
# this is the file in which I actually work with datas
library(rjson)
library(RPostgreSQL)

setwd("~/projects/categorizeML/")
login_info = fromJSON(file="login_info.json")
db = login_info$ML$database
host = login_info$hostname
user = login_info$username
pw = login_info$password

driver = dbDriver("PostgreSQL")
con = dbConnect(driver, dbname=db,
                host = host,
                port = 5432,
                user = user,
                password = pw)


dbarxivs = dbGetQuery(con, "SELECT note, url FROM link WHERE url LIKE '%arxiv%'")
# try to parse these
library("stringr")
dbarxivs$uri = str_match(dbarxivs$url, "arxiv.org/.../(\\d\\d\\d\\d[.]\\d\\d\\d\\d\\d?)")[,2]

# look at what's going on
dbarxivs[is.na(dbarxivs$uri),1:2]
# remove arxiv/bulk_data and arxiv-sanity
dbarxivs = dbarxivs[-c(230,325),]

# 58 duplicates
nrow(dbarxivs) - length(unique(dbarxivs$uri))


# import abstracts
abs = dbGetQuery(con,"SELECT title, summary, arxivid, doi, link,
               authorsaffil, categoryterms,
                published FROM paper")

dbDisconnect(con)
dbUnloadDriver(driver)

# label as in-interesting or not
  # check my db pull against arxiv pull
  sum(!dbarxivs$uri %in% abs$arxivid)
  mismatch = dbarxivs[!dbarxivs$uri %in% abs$arxivid,]
  
  # get url for more
  paste0("http://export.arxiv.org/api/query?search_query=",
    paste0("id:", mismatch$uri, collapse=" OR "),
  "&start=0&max_results=30")

  # check against my db pull
  abs$interest = abs$arxivid %in% dbarxivs$uri
  # check against lahwran's gist positive examples
  temp = read.delim("metadata/names_positive_examples",colClasses = "character", header=FALSE)
  
  # 4 differences
  sum(abs$arxivid %in% temp$V1 != abs$interest)
  abs$arxivid[abs$arxivid %in% temp$V1 != abs$interest]
    # interesting, my list doesn't have them. Indeed, they are not in there as links so I do not. I'll go fix 3/4 of those now

 # count the confusion matrix for base rate
 table(abs$interest) # 1626 false, 1314 true. 55.3% baseline

# get document term matrix for summary
library(tm)
corpus <- Corpus(VectorSource(tolower(abs$summary)))
corpus <- tm_map(corpus, removePunctuation)
corpus <- tm_map(corpus, removeWords, stopwords("english"))

library(SnowballC)
corpus <- tm_map(corpus, stemDocument)
corpus <- tm_map(corpus, stripWhitespace)

BigramTokenizer <- function(x) {
  unlist(lapply(ngrams(words(x), 2), paste, collapse = " "), use.names = FALSE)}

set.seed(461)
ttsplit = (sample(seq(corpus), length(corpus)) %% 20) == 7
testcorp = corpus[ttsplit]
traincorp = corpus[!ttsplit]
trainabs = abs[!ttsplit,]
testabs = abs[ttsplit,]

frequencies = DocumentTermMatrix(traincorp, control=list(tokenize = BigramTokenizer))
frequencies
frequencies.sparse = removeSparseTerms(frequencies, 0.993)
# dictionary=charactervector
 #http://www.r-bloggers.com/text-mining-the-complete-works-of-william-shakespeare/
# dummy categories
# 3,8,5,3,4
#abs$categoryterms[c(31,47,49,54,56)]
#str_match_all(abs$categoryterms[c(31,47,49,54,56)], "[{,;\" ]+(.+?)(?=[ },\"]+)")

# helper function
ragged_match = function(ragged_list) {
  allitems = sort(unique(unlist(sapply(ragged_list, function(x) {
    if (ncol(x) > 1) {
      return(as.vector(x[,2:ncol(x)], "character"))
    } else {
      print("oops nothing in this one")
    }
  }))))
  results = t(sapply(ragged_list, function(x, cols) as.numeric(cols %in% x[,2:ncol(x)]), allitems))
  colnames(results) = allitems
  return(results)
}

# check for zero-variances:
splitty = split(as.data.frame(as.matrix(frequencies.sparse)), trainabs$interest)
# True variances
tvar = apply(splitty$`TRUE`, 2, var)
tvar[tvar < 0.005]
# false variances
fvar = apply(splitty$`FALSE`, 2, var)
fvar[fvar < 0.001]

# catterms = str_match_all(abs$categoryterms, "[{,;\" (]+(.+?)(?=[ ;},\")]+)")
#catterms = str_match_all(abs$categoryterms, "[{,](.+?)(?=[},])|[\",;] ?((\d\d[-A-Z])[0-9x][0-9x])(?=[\",;])")

catterms = str_match_all(trainabs$categoryterms, "[{\",; ](([A-Z]\\.[0-9]*)(?:\\.[0-9m]*)?)(?:\\.[0-9a-z])?(?=[ \",;}])|[{\",; ]((\\d\\d[-A-Z])[0-9xX][0-9xX])(?=[ }\",;])|[{, ](([-a-zA-Z]*)(?:\\.[-a-zA-Z]*)?)(?=[ },])")

categories = ragged_match(catterms)
# 1602.01323 (row 1506) needs to add to 68U15, was mistyped as 6U815
seq_len(nrow(trainabs))[grepl("6U8",trainabs$categoryterms)]
categories[1425,"68U"] = 1
# remove Primary, Secondary, ""
categories = categories[,!colnames(categories) %in% c("theory",
                        "Secondary", "")]
# misccategory = rowSums(categories[,colSums(categories) <= 3])
# categories = cbind(categories[,colSums(categories) > 3], othercategory=misccategory)

# check for zero-variances:
splitty = split(as.data.frame(as.matrix(categories)), trainabs$interest)
# True variances
tvar = apply(splitty$`TRUE`, 2, var)
tvar[tvar < 5/nrow(categories)]
categories = categories[, tvar > 5/nrow(categories)]

splitty = split(as.data.frame(as.matrix(categories)), trainabs$interest)
# false variances
fvar = apply(splitty$`FALSE`, 2, var)
fvar[fvar < 5/nrow(categories)]
categories = categories[, fvar > 5/nrow(categories)]



library("Matrix")
# dummy authors
  authors = str_match_all(trainabs$authorsaffil, "\\{+\"?(.*?)\"?,(?:NULL|\"?(.*?)?\"?)\\}+")
  authorlist = sort(str_trim(unique(unlist(sapply(authors, function(x) x[,2])))))
  
  # construct a sparse matrix for authors
  i = c()
  j = c()
  for (rown in 1:length(authors)) {
    i = c(i, rep(rown, nrow(authors[[rown]])))
    j = c(j, match(str_trim(authors[[rown]][,2]),authorlist))
  }
  authors = sparseMatrix(i=i, j=j)
  colnames(authors) = authorlist
  # plot distribution of # papers contributed
  
  library("ggplot2")
  ggplot(data.frame(), aes(x=colSums(authors))) + geom_histogram()
  # 3 to 5 looks quite good, going to check how many actual papers that eliminates

  # check for zero-variances:
  splitty = split(as.data.frame(as.matrix(authors)), trainabs$interest)
  tvar = apply(splitty$`TRUE`, 2, var)
  fvar = apply(splitty$`FALSE`, 2, var)
  miscauthors = rowSums(authors[, tvar <= 2/nrow(authors) | fvar <= 2/nrow(authors)])
  authors = authors[, tvar > 2/nrow(authors) & fvar > 2/nrow(authors)]
  authors = cbind(authors, otherauthors=miscauthors)

# prepend dummied categories, authors
  inputvars = cbind(as.matrix(authors),categories, as.matrix(frequencies.sparse))
  # make sure no duplicated names
  sum(duplicated(c(colnames(authors), colnames(categories), colnames(frequencies.sparse))))
  inputvars = inputvars[,colnames(inputvars) != ""]
  save(inputvars, file="inputvars.rdata")
# naivebayes simple run
  library("klaR")
  model = NaiveBayes(inputvars, factor(trainabs$interest))
  modelsmooth = NaiveBayes(inputvars, factor(trainabs$interest), fL=.5)
  # get predictions matrix: is it better than base rate?
  results = predict(model)

  things = sapply(model$tables, function(x) {
    return(max(x[1,1]/x[2,1], x[2,2]/x[1,2]))
  })
  print(sort(things))
  things = sapply(model$tables, function(x) max(x[1,2]/x[2,2],x[1,1]/x[1,1]))
  print(sort(things))

library("pROC")
roc(trainabs$interest, results$posterior[,1], plot=TRUE)
#0.833
roc(trainabs$interest, results$posterior[,2], plot=TRUE)
#0.8376

sum((results$class == "TRUE") == trainabs$interest)/nrow(trainabs) # accuracy 79.83%

# naivebayes caret

# ways to improve: incorporate the date published
  # fiddle with the document term matrix, a la paul graham
 # make a special document term matrix of titles
  # see if I should exclude the items not seen in the original emails... how many are there to skew it? run again without them?
# dois - can I trust them to be valid, and tell which journal to expect things in?
# should totally import the authors and categories back properly
 
# do a logistic glm too.
# random forest
# ensemble method
# do a wordclouds! DO IT!