function [accuracy, sensitivity, specificity] = Evaluate(actual, predicted)
% This fucntion evaluates the performance of a classification model by 
% calculating the common performance measures: Accuracy, Sensitivity, 
% Specificity, Precision, Recall, F-Measure, G-mean.
% Input: ACTUAL = Column matrix with actual class labels of the training
%                 examples
%        PREDICTED = Column matrix with predicted class labels by the
%                    classification model
% Output: EVAL = Row matrix with all the performance measures


idx = (actual()==1);

p = length(actual(idx));
n = length(actual(~idx));
N = p+n;

tp = sum(actual(idx) == predicted(idx));
tn = sum(actual(~idx) == predicted(~idx));
fp = n - tn;
fn = p - tp;

tp_rate = tp/p;
tn_rate = tn/n;

accuracy = (tp+tn)/(tp+tn+fp+fn);
sensitivity = tp_rate;
specificity = tn_rate;
precision = tp/(tp+fp);
recall = sensitivity;
f_measure = 2*((precision*recall)/(precision + recall));
gmean = sqrt(tp_rate*tn_rate);

% if needed, get all
%result = [accuracy sensitivity specificity precision recall f_measure gmean];
