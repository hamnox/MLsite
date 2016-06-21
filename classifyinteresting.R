
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

frequencies = DocumentTermMatrix(traincorp, control=list(tokenize = "words"))
#frequencies2 = DocumentTermMatrix(traincorp, control=list(tokenize = BigramTokenizer))
frequencies
# check for zero variances:
#tvar = apply(frequencies[trainabs$interest,], 2, var)
#fvar = apply(frequencies[!trainabs$interest,], 2, var)
length(tvar[tvar > 0 & fvar > 0])

#frequencies.sparse = frequencies[,tvar > 0 & fvar > 0]
frequencies.sparse = removeSparseTerms(frequencies, 0.90)

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

# catterms = str_match_all(abs$categoryterms, "[{,;\" (]+(.+?)(?=[ ;},\")]+)")
#catterms = str_match_all(abs$categoryterms, "[{,](.+?)(?=[},])|[\",;] ?((\d\d[-A-Z])[0-9x][0-9x])(?=[\",;])")

catterms = str_match_all(trainabs$categoryterms, "[{\",; ]((([A-Z])\\.[0-9]*)(?:\\.[0-9m]*)?)(?:\\.[0-9a-z])?(?=[ \",;}])|[{\",; ](((\\d\\d)[-A-Z])[0-9xX][0-9xX])(?=[ }\",;])|[{, ](([-a-zA-Z]*)(?:\\.[-a-zA-Z]*)?)(?=[ },])")

categories = ragged_match(catterms)
# 1602.01323 (row 1506) needs to add to 68U15, was mistyped as 6U815
seq_len(nrow(trainabs))[grepl("6U8",trainabs$categoryterms)]
categories[1425,"68U"] = 1
categories[1425,"68"] = 1
# remove Primary, Secondary, ""
categories = categories[,!colnames(categories) %in% c("theory",
                        "Secondary", "")]
dim(categories) # 461 now
sparseness = colSums(categories) / nrow(categories)
categories = categories[,sparseness > .01]
# misccategory = rowSums(categories[,colSums(categories) <= 3])
# categories = cbind(categories[,colSums(categories) > 3], othercategory=misccategory)
# 
# # check for zero-variances:
# splitty = split(as.data.frame(as.matrix(categories)), trainabs$interest)
# # True variances
# tvar = apply(splitty$`TRUE`, 2, var)
# categories = categories[,tvar > 0]
# 
# splitty = split(as.data.frame(as.matrix(categories)), trainabs$interest)
# false variances
# fvar = apply(splitty$`FALSE`, 2, var)
# fvar[fvar < 5/nrow(categories)]
# categories = categories[, fvar > 0]



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

  # # check for zero-variances:
  # splitty = split(as.data.frame(as.matrix(authors)), trainabs$interest)
  # tvar = apply(splitty$`TRUE`, 2, var)
  # fvar = apply(splitty$`FALSE`, 2, var)
  # authors = authors[, tvar > 0 & fvar > 0]

sparseness = colSums(authors) / nrow(authors)
authors = authors[,sparseness > .004]
# prepend dummied categories, authors
  #colnames(categories) = paste0("category-",colnames(categories))
  inputvars = cbind(as.matrix(authors),categories, as.matrix(frequencies.sparse))
  # make sure no duplicated names
  sum(duplicated(c(colnames(authors), colnames(categories), colnames(frequencies.sparse))))

  #inputvars = inputvars[,colnames(inputvars) != ""]
  #inputvars = inputvars[,colnames(inputvars) != "category-"]

  save(categories, authors, trainabs, testabs, abs, dbarxivs, frequencies, frequencies.sparse, file = "savestuff.rdata")
# naivebayes simple run
  library("klaR")
  # remove zero variances
  tval = apply(inputvars[trainabs$interest,], 2, var)
  fval = apply(inputvars[!trainabs$interest,], 2, var)
  naiveinput = inputvars[,tval > 0 & fval > 0]
  
  model = NaiveBayes(naiveinput, factor(trainabs$interest))
  model2 = NaiveBayes(as.matrix(frequencies.sparse), factor(trainabs$interest))
  #modelsmooth = NaiveBayes(inputvars, factor(trainabs$interest), fL=.5)
  # get predictions matrix: is it better than base rate?
  results = predict(model)

library("pROC")
roc(trainabs$interest, results$posterior[,1], plot=TRUE)
# #0.833... #.8211 for simplified version
roc(trainabs$interest, results$posterior[,2], plot=TRUE)
# #0.8376... #.8234 for simplified version


sum((results$class == "TRUE") == trainabs$interest)/nrow(trainabs) # accuracy 63.9%.... #0.7816501 for simplified version

library("glmnet")
scaled_input = scale(inputvars)

model = cv.glmnet(scaled_input, trainabs$interest, family="binomial", type.measure="auc")
#model = cv.glmnet(scaled_input, trainabs$interest, family="binomial", type.measure="auc")

results = predict(model, newx = scaled_input,
                  s=model$lambda.min, type="response")
library("pROC")
roc(trainabs$interest, as.numeric(results), plot=TRUE)
#0.874 ROC with words
#0.9082 with bigrams
#0.8943 with simplified version

accuracy = sapply(seq(.2,.6,.01), function(x) sum((results > x) == trainabs$interest)/nrow(trainabs))
ggplot(data.frame()) + geom_point(aes(x=seq(.2,.6,.01), y=accuracy))

sum((results > .39) == trainabs$interest)/nrow(trainabs) # max words: accuracy 83.4%, half cutoff is 79.6^
# bigrams: accuracy 84.85%, half cutoff is .8293
# simplified is 0.8410384

# try a random forest
library("randomForest")
model = randomForest(scaled_input, y=trainabs$interest, ntree=50)

sum((model$predicted > .5) == trainabs$interest)/nrow(trainabs)
# bigrams: wow, 82.4 acurracy without optimizing.
# simplified is 82.9 accuracy

roc(trainabs$interest, model$predicted, plot=TRUE) # auc .8706
model$importance[order(model$importance),]
# most important are neural, network, neep, covolut, train, task, learn, category-cs.NE, recurr, dataset, architectur....

library("caret")
library("doParallel")
#??do
doMC::registerDoMC(cores=3)


set.seed(114)
control = trainControl(method="repeatedcv", repeats=3, number=10,
                       verboseIter=TRUE, allowParallel = TRUE)
                       #savePredictions = "final")

caret_fit = train(inputvars, factor(trainabs$interest,
                                    labels=c("fawse", "twue")),
                  trControl=control, method="parRF",
                  tuneLength=10, metric="Accuracy")

imps = caret_fit$finalModel$importance
imps = imps[order(imps),]
plot(imps)
results = predict(caret_fit, type="prob")

accuracy = sapply(seq(.1,.9,.01), function(x) sum((results[,1] < x) == trainabs$interest)/nrow(trainabs))
accuracy2 = sapply(seq(.1,.9,.01), function(x) sum((results[,2] > x) == trainabs$interest)/nrow(trainabs))
ggplot(data.frame()) + geom_point(aes(x=seq(.1,.9,.01), y=accuracy), alpha=0.5) + geom_point(aes(x=seq(.1,.9,.01)), y=accuracy2, color="red")
# woah 100% accuracy... let's try with test shall we?

testfrequencies = DocumentTermMatrix(testcorp, control=list(tokenize = "words", dictionary=colnames(frequencies.sparse)))

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
testabs$authorsaffil[84]
testauthors[84,"Sergey Levine"]

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
# 80% accuracy at 0.5, great.

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