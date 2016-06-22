
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

set.seed(3506)
ttsplit = (sample(seq(corpus), length(corpus)) %% 20) == 7
testcorp = corpus[ttsplit]
traincorp = corpus[!ttsplit]
trainabs = abs[!ttsplit,]
testabs = abs[ttsplit,]

frequencies = DocumentTermMatrix(traincorp, control=list(tokenize = "words"))
#frequencies2 = DocumentTermMatrix(traincorp, control=list(tokenize = BigramTokenizer))
frequencies

# visualize cutoff points
sparseness = colSums(as.matrix(frequencies))/nrow(frequencies)
sparseness = data.frame(x=seq(0,1,.01), y=sapply(seq(0,1,.01), function(x) sum(sparseness > x)))
ggplot(sparseness[2:40,], aes(x=x, y=y)) + geom_point()

frequencies.sparse = removeSparseTerms(frequencies, 0.93)


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

catterms = str_match_all(trainabs$categoryterms, "[{\",; ]((([A-Z])\\.[0-9]*)(?:\\.[0-9m]*)?)(?:\\.[0-9a-z])?(?=[ \",;}])|[{\",; ](((\\d\\d)[-A-Z])[0-9xX][0-9xX])(?=[ }\",;])|[{, ](([-a-zA-Z]*)(?:\\.[-a-zA-Z]*)?)(?=[ },])")

categories = ragged_match(catterms)
# 1602.01323 (row 1506) needs to add to 68U15, was mistyped as 6U815
seq_len(nrow(trainabs))[grepl("6U8",trainabs$categoryterms)]
categories[1430,"68U"] = 1
categories[1430,"68"] = 1
# remove Primary, Secondary, ""
categories = categories[,!colnames(categories) %in% c("theory",
                        "Secondary", "")]
dim(categories) # 456 now

# visualize cutoff points
sparseness = colSums(categories) / nrow(categories)
plotty = data.frame(x=seq(0,.1,.001), y=sapply(seq(0,.1,.001), function(x) sum(sparseness > x)))
ggplot(plotty[1:20,], aes(x=x, y=y)) + geom_point()
categories = categories[,sparseness > 0.003] # 79 categories


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

sparseness = colSums(authors) / nrow(authors)
plotty = data.frame(x=seq(0,.1,.001), y=sapply(seq(0,.1,.001), function(x) sum(sparseness > x)))
ggplot(plotty[2:20,], aes(x=x, y=y)) + geom_point()
authors = authors[,sparseness > 0.002] # 85 categories

# prepend dummied categories, authors
  inputvars = cbind(as.matrix(authors),categories, as.matrix(frequencies.sparse))
  # make sure no duplicated names
  sum(duplicated(c(colnames(authors), colnames(categories), colnames(frequencies.sparse))))

# naivebayes simple run
  library("klaR")
  # remove zero variances
  tval = apply(inputvars[trainabs$interest,], 2, var)
  fval = apply(inputvars[!trainabs$interest,], 2, var)
  # 30 to be removed
  naiveinput = inputvars[,tval > 0 & fval > 0]
  
  model = NaiveBayes(naiveinput, factor(trainabs$interest))
  # get predictions matrix: is it better than base rate?
  results = predict(model)

library("pROC")
roc(trainabs$interest, results$posterior[,1], plot=TRUE)
#0.7914
roc(trainabs$interest, results$posterior[,2], plot=TRUE)
#0.7993


sum((results$class == "TRUE") == trainabs$interest)/nrow(trainabs) # 76.81%

accuracy = sapply(seq(0,1,.05), function(x) sum((results$posterior[,2] > x) == trainabs$interest, na.rm=TRUE)/nrow(trainabs))
ggplot(data.frame()) + geom_point(aes(seq(0,1,.05), accuracy))
sum((results$posterior[,2] > .76)==trainabs$interest, na.rm = TRUE)/nrow(trainabs) # 76.849%


library("glmnet")
scaled_input = scale(inputvars)

model = cv.glmnet(scaled_input, trainabs$interest, family="binomial", type.measure="auc")
#model = cv.glmnet(scaled_input, trainabs$interest, family="binomial", type.measure="auc")

results = predict(model, newx = scaled_input,
                  s=model$lambda.min, type="response")
library("pROC")
roc(trainabs$interest, as.numeric(results), plot=TRUE)
#0.9129 auc

accuracy = sapply(seq(.2,.6,.01), function(x) sum((results > x) == trainabs$interest)/nrow(trainabs))
ggplot(data.frame()) + geom_point(aes(x=seq(.2,.6,.01), y=accuracy))

sum((results > .41) == trainabs$interest)/nrow(trainabs)
# 85.4% accuracy

# try this with test data, see below random forests for generating
scaledtestinputvars = scale(testinputvars,
                center = attr(scaled_input, "scaled:center"),
                scale = attr(scaled_input, "scaled:scale"))
results = predict(model, newx=scaledtestinputvars, type="response")
roc(testabs$interest, as.numeric(results), plot=TRUE) # 0.881
accuracy = sapply(seq(.1,.9,.01), function(x) sum((results > x) == testabs$interest)/nrow(testabs))
ggplot(data.frame()) + geom_point(aes(x=seq(.1,.9,.01), y=accuracy), alpha=0.5) # 86.48% accuracy

# try a random forest
library("randomForest")
model = randomForest(scaled_input, y=trainabs$interest, ntree=50)

sum((model$predicted > .5) == trainabs$interest)/nrow(trainabs)
#82%

roc(trainabs$interest, model$predicted, plot=TRUE) # auc .8656
model$importance[order(model$importance),]
# most important are neural, network, neep, covolut, train, task, learn, category-cs.NE, recurr, dataset, architectur....

save(scaled_input, categories, authors, frequencies.sparse, file = "savestuff.rdata")

library("caret")
library("doParallel")
#??do
doMC::registerDoMC(cores=4)


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