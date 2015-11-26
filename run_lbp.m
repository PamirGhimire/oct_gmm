clc; clear all; close all;


%% Some parameters for the algorithm

dataset = 'SERI';
num_vols = 16;
pca_k = 200;
frames_per_vol = 128; % for SERI
total_frames = num_vols*frames_per_vol;
train_frames = 12*frames_per_vol; 
mahal_thresh = chi2inv(0.95, pca_k);
do_preprocess = 0;
GMM_Ks = [2 3 5 8 10 12 15];


%% Read data and pre-process them for flattening

if (do_preprocess)
    [X_vols] = preprocess('data/normal/normal',num_vols, dataset, 'lbp');
    [Y_vols] = preprocess('data/DME/patient',num_vols, dataset, 'lbp');
else
    % load already pre-processed and stored data
    X_vols = load('X_seri_lbp');
    X_vols = X_vols.X_vols;
    Y_vols = load('Y_seri_lbp');
    Y_vols = Y_vols.Y_vols;
end

%% Choose the best model parameter
% to find the best K value for GMM

clc;
num_iter = 1;
[avg_diseased, used_vols, x_test_vols] = train_gmm(X_vols, pca_k, GMM_Ks, 'lbp', num_iter, dataset);
% Using the best average values, choose the best K value for final GMM
fprintf('Best K for GMM is: %d \n', GMM_Ks(find(avg_diseased == min(avg_diseased)))); 
best_gmm_k = max(GMM_Ks(find(avg_diseased == min(avg_diseased))));


%% Fit the final model with all the used volumes

X = get_features(used_vols, 'lbp', dataset);
[X_train, X_mapping] = do_pca(X',pca_k);

options = statset('Display','final','MaxIter',1000);
% final model with the best K value for GMM
% train with all training data
obj = gmdistribution.fit(X_train,best_gmm_k, ...
                            'Options',options, ...
                            'Regularize',0.001, ...
                            'Start', 'randSample', ...
                            'CovType', 'diagonal', ...
                            'Replicates', 5, ...
                            'Start', 'randSample');

diseased_vol_thresh = get_disease_thresh(obj, X_train, used_vols, best_gmm_k, mahal_thresh);
                        
% Now test with the obtained model 
[actual_idx, predicted_idx] = test_gmm(obj, x_test_vols, Y_vols, ...
            dataset, pca_k, best_gmm_k, mahal_thresh, diseased_vol_thresh, 'lbp');

% report accuracies now
[accuracy, sensitivity, specificity] = validate(actual_idx, predicted_idx);
fprintf('Accuracy is: %f, \n sensitivity is: %f \n specificity is: %f \n',  ...
            accuracy, sensitivity, specificity); 

% Method 2: %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Extract LBP features and form the X matrix
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% if (do_preprocess)
%     [X f_vols] = preprocess('data/normal/normal',num_vols, dataset, 'lbp');
% else
%     X = load('X_filtered_lbp');
%     X = X.X;
% end
% 
% [X_res, x_mapping] = do_pca(X',pca_k);
% disp('Done with PCA of X');
% fprintf('Variance retained after PCA is: %f \n', ...
%          sum(x_mapping.lambda(1:pca_k))/sum(x_mapping.lambda));
% 
% if (do_preprocess)
%     Y = preprocess('data/DME/patient',num_vols, dataset, 'lbp');
% else
%     Y = load('Y_filtered_lbp');
%     Y = Y.Y;
% end
% [Y_res, y_mapping] = do_pca(Y',pca_k);
% disp('Done with PCA of Y');
% fprintf('Variance retained after PCA is: %f \n', ...
%          sum(y_mapping.lambda(1:pca_k))/sum(y_mapping.lambda));

%% Fit GMM and do cross validation to arrive at GMM K value
% 
% clc;
% clear total_diseased;
% GMM_Ks = [2 3 5 8 10 12 15];
% options = statset('Display','off','MaxIter',1000);
% 
% 
% for ii = 1:length(GMM_Ks)
%     gmm_k = GMM_Ks(ii);
%     
%     obj = gmdistribution.fit(X_res(1:train_frames,:),gmm_k, ...
%                             'Options',options, ...
%                             'Regularize',0.001, ...
%                             'Start', 'randSample', ...
%                             'CovType', 'diagonal', ...
%                             'Replicates', 5, ...
%                             'Start', 'randSample');
% 
%     outliers = {};
%     x_outliers = [];
%     n = 1; % count number of outliers
%     frame_no = 1; % frame number in the volume
%     vol = 1;
%     for i = train_frames+1:total_frames
%        %frame_dists(n) = norm(X_res(i,:) - gmm_means);
%        [x_outliers(n)] = check_outlier(...
%                                   obj, Y_res(i,:), gmm_k, mahal_thresh);
%        n = n+1;
%        frame_no = frame_no+1;
% 
%         % reset for next volume
%         if (frame_no > frames_per_vol) 
%             outliers{vol} = x_outliers;
%             frame_no = 1;
%             vol = vol+1;
%             n = 1;
%             x_outliers = [];
%         end
%     end
% 
%     % Analyse the outliers obtained
%     diseased_frames = 0;
%     diseased_vols = 0;
%     for i = 1:length(outliers)
%         fprintf('Outliers in Vol %d are: %d \n', i, sum(outliers{i}));
%         if (sum(outliers{i}) > diseased_vol_thresh)
%            diseased_vols = diseased_vols+1;
%            diseased_frames = diseased_frames + sum(outliers{i});
%            %fprintf('diseased vol number is: %d \n', i);
%         end
%     end
%     
%     fprintf('For GMM k value: %d \n', gmm_k);
%     fprintf('Total diseased volumes are: %d, total diseased frames are: %d \n',...
%             diseased_vols, diseased_frames);
%     
%     total_diseased(ii) = diseased_frames;
% end
% 
% % Choose the best K value for GMM. 
% % We choose the K that returns the least number of diseased frames
% % If more than 2 Ks are best, chose the  min.
% best_gmm_k = max(GMM_Ks(find(total_diseased == min(total_diseased))));
% fprintf('Best GMM K value is: %f \n',best_gmm_k);
% 
% %% Classification of diseased volumes
% % To run this step, run the GMM fit step for all volumes.
% 
% clc;
% outliers = {};
% y_outliers = [];
% n = 1; % count number of outliers
% frame_no = 1; % frame number in the volume
% vol = 1;
% options = statset('Display','final','MaxIter',1000);
% 
% % final model with the best K value for GMM
% % train with all training data
% obj = gmdistribution.fit(X_res,best_gmm_k, ...
%                             'Options',options, ...
%                             'Regularize',0.001, ...
%                             'Start', 'randSample', ...
%                             'CovType', 'diagonal', ...
%                             'Replicates', 5, ...
%                             'Start', 'randSample');
% 
% for i = 1:total_frames
%     [y_outliers(n)] = check_outlier(...
%                             obj, Y_res(i,:),best_gmm_k, mahal_thresh);
%     n = n+1;
%     frame_no = frame_no+1;
%     % reset for next volume
%     if (frame_no > frames_per_vol) 
%         outliers{vol} = y_outliers;
%         frame_no = 1;
%         vol = vol+1;
%         n = 1;
%         y_outliers = [];
%     end
% end
% 
% % Analyse the outliers obtained
% diseased_frames = 0;
% diseased_vols = 0;
% for i = 1:length(outliers)
%     if (sum(outliers{i}) > diseased_vol_thresh)
%        diseased_vols = diseased_vols+1;
%        diseased_frames = diseased_frames + sum(outliers{i});
%        fprintf('diseased vol number is: %d \n', i);
%     end
% end
% fprintf('Diseased volumes are: %d, total diseased frames are: %d \n',...
%         diseased_vols, diseased_frames);
    
    