
# this is the file in which I actually work with datas
library(rjson)
library(RPostgreSQL)
library("ggplot2")

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


# take non-neural stuff
dbarxivs = dbGetQuery(con, "SELECT link.note, link.url FROM link
                      LEFT JOIN tag ON link.note = tag.note
                      WHERE link.url LIKE '%arxiv%' AND NOT tagname LIKE '%non%'")
# try to parse these
library("stringr")
dbarxivs$uri = str_match(dbarxivs$url, "arxiv.org/.../(\\d\\d\\d\\d[.]\\d\\d\\d\\d\\d?)(?:v\\d)?(?:[.]pdf)?$")[,2]

# look at what's going on
dbarxivs[is.na(dbarxivs$uri),1:3]
dbarxivs[4018:4019,3] = "1604.01277"
dbarxivs = dbarxivs[-c(404,536),]

# 3053 duplicates
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
dbarxivs[!dbarxivs$uri %in% abs$arxivid,]

# get url for more
# paste0("http://export.arxiv.org/api/query?search_query=",
#   paste0("id:", mismatch$uri, collapse=" OR "),
# "&start=0&max_results=30")

# check against my db pull
abs$interest = abs$arxivid %in% dbarxivs$uri
# check against lahwran's gist positive examples
temp = read.delim("metadata/names_positive_examples",colClasses = "character", header=FALSE)

# 8 differences, from non-neural, except 15.05008
sum(abs$arxivid %in% temp$V1 != abs$interest)
abs$arxivid[abs$arxivid %in% temp$V1 != abs$interest]

# count the confusion matrix for base rate
table(abs$interest) # 1633 false, 1327 true. 44.83% baseline


library(tm)
corpus <- Corpus(VectorSource(tolower(abs$summary)))
corpus <- tm_map(corpus, removePunctuation)
corpus <- tm_map(corpus, removeWords, stopwords("english"))

library(SnowballC)
corpus <- tm_map(corpus, stemDocument)
corpus <- tm_map(corpus, stripWhitespace)

BigramTokenizer <- function(x) {
  unlist(lapply(ngrams(words(x), 2), paste, collapse = " "), use.names = FALSE)}

frequencies = DocumentTermMatrix(corpus, control=list(tokenize = "words"))
#frequencies2 = DocumentTermMatrix(traincorp, control=list(tokenize = BigramTokenizer))

# visualize cutoff points
sparseness = colSums(as.matrix(frequencies) == 0)/nrow(frequencies)
sparseness = data.frame(x=seq(0,1,.01), y=sapply(seq(0,1,.01), function(x) sum(sparseness > x)/ncol(frequencies)))
ggplot(sparseness[50:100,], aes(x=x, y=y)) + geom_point()

frequencies.sparse = removeSparseTerms(frequencies, 0.91)

titles <- Corpus(VectorSource(tolower(abs$title)))
titles <- tm_map(titles, removePunctuation)
titles <- tm_map(titles, removeWords, stopwords("english"))
titles <- tm_map(titles, stemDocument)
titles <- tm_map(titles, stripWhitespace)
titlefreq = DocumentTermMatrix(titles, control=list(tokenize = "words"))
sparseness = colSums(as.matrix(titlefreq) == 0)/nrow(titlefreq)
sparseness = data.frame(x=seq(0,1,.01), y=sapply(seq(0,1,.01), function(x) sum(sparseness > x)/ncol(frequencies)))
ggplot(sparseness[50:100,], aes(x=x, y=y)) + geom_point()
titlefreq
titlefreq.sparse = removeSparseTerms(titlefreq, 0.96)

  # get url for more
  listofids = c("1203.2928")
  paste0("http://export.arxiv.org/api/query?search_query=",
    paste0("id:", listofids, collapse=" OR "),
  "&start=0&max_results=",length(listofids)+2)

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



catterms = str_match_all(abs$categoryterms, "[{\",; ]((([A-Z])\\.[0-9]*)(?:\\.[0-9m]*)?)(?:\\.[0-9a-z])?(?=[ \",;}])|[{\",; ](((\\d\\d)[-A-Z])[0-9xX][0-9xX])(?=[ }\",;])|[{, ](([-a-zA-Z]*)(?:\\.[-a-zA-Z]*)?)(?=[ },])")

categories = ragged_match(catterms)
# 1602.01323 (row 1506) needs to add to 68U15, was mistyped as 6U815
seq_len(nrow(abs))[grepl("6U8",abs$categoryterms)]
categories[1506,"68U"] = 1
categories[1506,"68"] = 1
# remove Primary, Secondary, ""
categories = categories[,!colnames(categories) %in% c("theory",
                                                      "Secondary", "")]
dim(categories) # 472 now

# visualize cutoff points
sparseness = colSums(categories) / nrow(categories)
plotty = data.frame(x=seq(0,.1,.001), y=sapply(seq(0,.1,.001), function(x) sum(sparseness < x)/nrow(categories)))
ggplot(plotty[1:50,], aes(x=x, y=y)) + geom_point()
categories = categories[,sparseness > 0.005] # 56 categories



library("Matrix")
# dummy authors
authors = str_match_all(abs$authorsaffil, "\\{+\"?(.*?)\"?,(?:NULL|\"?(.*?)?\"?)\\}+")
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

# visualize cutoff points
sparseness = colSums(authors) / nrow(authors)
plotty = data.frame(x=seq(0,.01,.0001), y=sapply(seq(0,.01,.0001), function(x) sum(sparseness < x)/nrow(authors)))
ggplot(plotty[1:25,], aes(x=x, y=y)) + geom_point()


authors = authors[,sparseness > 0.002] # 165 authors


numauthors = data.frame(NUMAUTHORS = rowSums(authors))








# make sure no duplicated names
intitles = titlefreq.sparse
colnames(intitles) = paste0("TITLE_",colnames(intitles))

sum(duplicated(c(
  colnames(authors),
  "NUMAUTHORS",
  colnames(categories),
  colnames(frequencies.sparse),
  colnames(intitles))))

# prepend dummied stuff
inputvars = cbind(as.matrix(authors), numauthors, categories, as.matrix(frequencies.sparse), as.matrix(intitles))
# 323 variables

load("savestuff.rdata")
#save(inputvars, abs, dbarxivs, file="savestuff.rdata")

library("caret")
library("doMC")
#??do
doMC::registerDoMC(cores=6)
registerDoMC(cores = 3)


set.seed(47)
control = trainControl(method="repeatedcv", repeats=3, number=10,
                       verboseIter=TRUE, allowParallel = TRUE)
                       #savePredictions = "final")

caret_fit = train(inputvars, factor(abs$interest,
                                    labels=c("False", "True")),
                  trControl=control, method="parRF",
                  tuneLength=10, metric="Accuracy")











# authors = 1-104
# numauthors = 105
# category = 106-161
# words = 162-289
# TITLE = 290-301
# get test authors



testauthors = str_match_all(testabs$authorsaffil, "\\{+\"?(.*?)\"?,(?:NULL|\"?(.*?)?\"?)\\}+")

# construct a sparse matrix for testauthors
i = c()
j = c()
for (rown in 1:length(testauthors)) {
  #if (!is.na(match(str_trim(testauthors[[rown]][,2]),colnames(authors)))) {
  i = c(i, rep(rown, nrow(testauthors[[rown]])))
  j = c(j, match(str_trim(testauthors[[rown]][,2]),
                 colnames(authors)))
  #}
}
i = i[!is.na(j)]
j = j[!is.na(j)]
testauthors = sparseMatrix(i=i, j=j,
                           dims=c(nrow(testabs),ncol(authors)))
colnames(testauthors) = colnames(authors)
# check that this worked
testabs$authorsaffil[53]
testauthors[53,testauthors[53,]]

# test categories
testcatterms = str_match_all(testabs$categoryterms, "[{\",; ]((([A-Z])\\.[0-9]*)(?:\\.[0-9m]*)?)(?:\\.[0-9a-z])?(?=[ \",;}])|[{\",; ](((\\d\\d)[-A-Z])[0-9xX][0-9xX])(?=[ }\",;])|[{, ](([-a-zA-Z]*)(?:\\.[-a-zA-Z]*)?)(?=[ },])")

testcategories = ragged_match(testcatterms)
undone = colnames(categories)[!colnames(categories) %in% colnames(testcategories)]
undone = matrix(rep(0, length(undone) * nrow(testcategories)),
                ncol=length(undone),
                dimnames = list(NULL,undone))
testcategories = cbind(testcategories, undone)
testcategories = testcategories[,colnames(categories)]

# put together
testinputvars = cbind(as.matrix(testauthors),testcategories, as.matrix(testfrequencies))

results = predict(caret_fit, newdata=testinputvars, type="prob")

accuracy = sapply(seq(0,1,.01), function(x) sum((results[,1] < x) == testabs$interest)/nrow(testabs))
accuracy2 = sapply(seq(0,1,.01), function(x) sum((results[,2] > x) == testabs$interest)/nrow(testabs))
ggplot(data.frame()) + geom_point(aes(x=seq(0,1,.01), y=accuracy), alpha=0.5) + geom_point(aes(x=seq(0,1,.01)), y=accuracy2, color="red")
# max 87.16% accuracy
roc(testabs$interest, results[,1], plot=TRUE) # .8978

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