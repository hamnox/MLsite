
# testing parser
sample_text = c('http://arxiv.org/abs/1602.04062 [abs] using reinforcement learning to entirely automatically tune hyperparameters!! about damn fucking time! should go in "hyperparameters", "rl". they also do some interesting investigation into what are good strategies based on the learned behaviors.',
'http://arxiv.org/abs/1602.04133 [abs] more progress in using deep gaussian processes as deep bayesian neural networks. should go in "gaussian processes", "bayesian neural networks". very interesting, I wonder if this will take over in a year or two?',
'http://arxiv.org/abs/1602.04868 [abs] real time face recognition on mobile devices. should go in "speed", "images/faces". they implement it on mobile gpus.',
'http://arxiv.org/abs/1602.09065 [abs] dataset for sign language gesture recognition, and some pose recognition experiments on it. should go in "images/pose" and maybe "language/speech" and "datasets".',
'http://arxiv.org/abs/1603.00550 [abs] "zero-shot learning" by using descriptions of classes without examples and doing some sort of regularization with them. interesting. should go in "classification", "generalization", maybe "transfer learning", "regularization". sounds like it works really really well, and this is a really cool topic.')
test = c("and and and and and", "fjdfjdand", "and", "", "wemciwomvisoidvj", "and fjfjfjfj and")
  gsub("and", test, ignore.case=TRUE)

library("stringr")
get_possible_categories = function(sample_text) {
  possible_categories = stringr::str_match_all(sample_text,
                                "(?:,|and|or|maybe|in)? \"(.*?)\"")
  return(sapply(possible_categories, function(x) x[,-1]))
}

possible_categories = get_possible_categories(sample_text)
ragged_list_to_matrix = function() {}
rowmax = max(sapply(possible_categories, length))

possible_categories = t(sapply(possible_categories, function(x, rowmax) x[rep(TRUE, rowmax)], rowmax))
possible_categories

install.packages("e1071")
library("e1071")
naiveBayes()