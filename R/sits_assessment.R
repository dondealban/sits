# ---------------------------------------------------------------
#
#  This file contain a list of functions to assess the quality of classified time series
#  it includes functions for cross_validation and accuracy
#  It works with SITS tables where the time series have been classified

#' @title Area-weighted post-classification accuracy assessment of classified maps
#' @name sits_accuracy_area
#' @author Victor Maus, \email{vwmaus1@@gmail.com}
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#'
#' @description To use this function, the input table should be a set of results containing
#' both the label assigned by the user and the classification result.
#' Accuracy assessment set us a confusion matrix to determine the accuracy of your classified result.
#' This function uses an area-weighted technique proposed by Olofsson et al. to
#' produce accuracy estimates that are more reliable
#'
#' We plan to do an improved version of this function that includes a Raster R object
#' with the classified map and a vector with the labels of the classified map
#' (Gilberto-Rolf-05-Jun-2017)
#'
#' This function calls \code{\link[dtwSat]{twdtwAssess}} from \pkg{dtwSat}.
#' \code{\link[dtwSat]{twdtwAssess}} performs an accuracy assessment of the classified, including
#' Overall Accuracy, User's Accuracy, Produce's Accuracy, error matrix (confusion matrix),
#' and estimated area according to [1-2].
#'
#' @references
#' [1] Olofsson, P., Foody, G.M., Stehman, S.V., Woodcock, C.E. (2013).
#' Making better use of accuracy data in land change studies: Estimating
#' accuracy and area and quantifying uncertainty using stratified estimation.
#' Remote Sensing of Environment, 129, pp.122-131.
#'
#' @references
#' [2] Olofsson, P., Foody G.M., Herold M., Stehman, S.V., Woodcock, C.E., Wulder, M.A. (2014)
#' Good practices for estimating area and assessing accuracy of land change. Remote Sensing of
#' Environment, 148, pp. 42-57.
#'
#' @param results.tb a sits table with a set of lat/long/time locations  with known and trusted labels and
#' with the result of classification method
#' @param area a list with the area of each label
#' @param conf.int specifies the confidence level (0-1).
#' @param rm.nosample if sum of columns and sum of rows of the error matrix are zero
#' then remove class. Default is TRUE.
#'@export
sits_accuracy_area <- function (results.tb, area, conf.int = 0.95, rm.nosample = FALSE){

     # Get reference classes
     references <- results.tb$label

     # Get mapped classes
     # mapped    <- dplyr::bind_rows(results.tb$distances) %>%
     #                          dplyr::select(dplyr::matches("classification")) %>% unlist

     # create a vector to store the result of the predictions
     mapped <- results.tb$class
     # Get all labels
     classes   <- unique(c(references, mapped))

     # Create error matrix
     error_matrix <- table(factor(mapped,     levels = classes, labels = classes),
                           factor(references, levels = classes, labels = classes))

     # Get area - TO IMPROVE USING THE METADATA FROM SATELLITE PRODUCTS
     if(missing(area))
          area <- rowSums(error_matrix)

     # Compute accuracy metrics using dtwSat::twdtwAssess
     assessment <- dtwSat::twdtwAssess (error_matrix,
                                        area = area,
                                        conf.int = conf.int,
                                        rm.nosample = rm.nosample )

     return (assessment)

}

#' @title Post-classification accuracy assessment of classified maps (non-weigthed)
#' @name sits_accuracy
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#'
#' @description To use this function, the input table should be a set of results containing
#' both the label assigned by the user and the classification result.
#' Accuracy assessment set us a confusion matrix to determine the accuracy of your classified result.
#' This function does not use an area-weigthed technique and should be used only as a
#' first check of accuracy. When the area of each class for the region of interest is available,
#' please use sits_accuracy_area instead
#'
#' @param results.tb   a sits table with a set of lat/long/time locations with known and trusted labels and
#' with the result of a classification method
#' @return assessment  a list containing overall accuracy, producers and users accuracy, and confusion matrix.
#'@export
sits_accuracy <- function (results.tb){

     # get reference classes
     ref.vec <- results.tb$label

     # create a vector to store the result of the predictions
     pred.vec <- results.tb$class

     # classification accuracy measures
     assessment <- .sits_accuracy(pred.vec, ref.vec)

     return (assessment)
}

#' @title Cross-validate temporal patterns
#' @name sits_cross_validate
#' @author Rolf Simoes, \email{rolf.simoes@@inpe.br}
#' @author Victor Maus, \email{vwmaus1@@gmail.com}
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#'
#' @description Splits the set of time series into training and validation and
#' perform cross-validation.
#' Cross-validation is a model validation technique for assessing how the results
#' of a statistical analysis will generalize to an independent data set.
#' It is mainly used in settings where the goal is prediction,
#' and one wants to estimate how accurately a predictive model will perform in practice.
#' One round of cross-validation involves partitioning a sample of data
#' into complementary subsets, performing the analysis on one subset
#' (called the training set), and validating the analysis on the other subset
#' (called the validation set or testing set).
#' To reduce variability, multiple rounds of cross-validation
#' are performed using different partitions,
#' and the validation results are averaged over the rounds.
#'
#' This function returns the Overall Accuracy, User's Accuracy,
#' Producer's Accuracy, error matrix (confusion matrix), and Kappa values.
#'
#' @param data.tb         a SITS tibble
#' @param method          method to create patterns ("gam", "dendogram" or "centroids")
#' @param bands           the bands used for classification
#' @param times           number of partitions to create.
#' @param perc            the percentage of data that goes to training.
#' @param from            starting date of the estimate in month-day (for "gam" method)
#' @param to              end data of the estimated in month-day (for "gam" method)
#' @param freq            int - the interval in days for the estimates to be generated
#' @param formula         the formula to be applied in the estimate (for "gam" method)
#' @param tw_alpha        (double) - the steepness of the logistic function used for temporal weighting
#' @param tw_beta         (integer) - the midpoint (in days) of the logistic function
#' @param tw_theta        numeric between 0 and 1. The weight of the time for the TWDTW computation. Use theta=0 to cancel the time-weight, i.e. to run the original DTW algorithm. Default is 0.5. For details see dtwSat::twdtwApply help.
#' @param tw_span         A number. Span between two matches, i.e. the minimum interval between two matches, for details see dtwSat::twdtwApply help.
#' @param interval        A character with the intevals size, e.g. "6 month".
#' @param overlap         A number between 0 and 1. The minimum overlapping between one match and the interval of classification. Default is 0.5. For details see dtwSat::twdtwApply help.
#' @param n_clusters      the maximum number of clusters to be identified (for clustering methods)
#' @param grouping_method the agglomeration method to be used. Any `hclust` method (see `hclust`) (ignored in `kohonen` method). Default is 'ward.D2'.
#' @param unsupervised    if TRUE, proceeds an unsupervised cluster followed by a relabel taking original label majority (
#' this option has not any effect if method == "gam")
#' @param min_clu_perc    the minimum percentagem of valid cluster members, with reference to the total number of samples (for clustering methods)
#' @param apply_gam       apply gam method after a clustering algorithm (ignored if method is `gam`).
#' @param koh_xgrid       x dimension of the SOM grid (used only in `kohonen` or `kohonen-dendogram` methods). Defaul is 5.
#' @param koh_ygrid       y dimension of the SOM grid (used only in `kohonen` or `kohonen-dendogram` methods). Defaul is 5.
#' @param koh_rlen        the number of times the complete data set will be presented to the SOM grid.
#' (used only in `kohonen` or `kohonen-dendogram` methods). Default is 100.
#' @param koh_alpha       learning rate, a vector of two numbers indicating the amount of change.
#' Default is to decline linearly from 0.05 to 0.01 over rlen updates.
#' @param file            file to save the results
#' @param .multicores     number of threads to process the validation (Linux only). Each process will run a whole partition validation (see `times` parameter).
#' @param ...             any additional parameters to be passed to `sits_pattern` function.
#' @return cm             a validation assessment
#' @export

# method = "gam", bands = NULL, from = NULL, to = NULL, freq = 8,
# formula = y ~ s(x), n_clusters = 2, grouping_method = "ward.D2", min_clu_perc = 0.10, apply_gam = FALSE,
# koh_xgrid = 5, koh_ygrid = 5, koh_rlen = 100, koh_alpha = c(0.05, 0.01)

sits_cross_validate <- function (data.tb, method = "gam", bands = NULL, times = 100, perc = 0.1,
                           from = NULL, to = NULL, freq = 8, formula = y ~ s(x),
                           tw_alpha = -0.1, tw_beta = 100, tw_theta = 0.5, tw_span = 0,
                           interval = "12 month", overlap = 0.5,
                           n_clusters = 2, grouping_method = "ward.D2", unsupervised = FALSE, min_clu_perc = 0.10,
                           apply_gam = FALSE, koh_xgrid = 5, koh_ygrid = 5, koh_rlen = 100, koh_alpha = c(0.05, 0.01),
                           file = "./conf_matrix.json", .multicores = 1, ...){

          ensurer::ensure_that (data.tb, !("NoClass" %in% sits_labels(.)$label),
                                 err_desc = "sits_cross_validate: please provide a labelled set of time series")

     # auxiliary function to classify a single partition
     .sits_classify_partitions <- function (p) {
          #
          message("Creating patterns from a data sample...")

          # use the extracted partition to create the patterns
          patterns.tb <- sits_patterns(p, method = method, bands = bands, from = from, to = to, freq = freq,
                                       formula = formula, n_clusters = n_clusters, grouping_method = grouping_method,
                                       min_clu_perc = min_clu_perc, apply_gam = apply_gam,
                                       koh_xgrid = koh_xgrid, koh_ygrid = koh_ygrid, koh_rlen = koh_rlen, koh_alpha = koh_alpha,
                                       unsupervised = unsupervised, show = FALSE, ...)

          # use the rest of the data for classification
          non_p.tb <- dplyr::anti_join(data.tb, p, by = c("longitude", "latitude", "start_date", "end_date", "label", "coverage"))

          # classify data
          matches.tb  <- sits_TWDTW_matches (non_p.tb, patterns.tb, bands = bands, alpha = tw_alpha, beta = tw_beta, theta = tw_theta, span = tw_span)
          class.tb    <- sits_TWDTW_classify (matches.tb, interval = interval, overlap = overlap)
          # retrieve the reference labels
          ref.vec <- as.character(class.tb$label)
          # retrieve the predicted labels
          pred.vec  <- as.character(
               purrr::map(class.tb$best_matches, function (e) as.character(e$label)))

          return (c(pred.vec, ref.vec))
     }
     # does the input data exist?
     ensurer::ensure_that(data.tb, !purrr::is_null(.),
                          err_desc = "sits_cross_validate: input data not provided")
     # are the bands to be classified part of the input data?
     ensurer::ensure_that(data.tb, !(FALSE %in% bands %in% (sits_bands(.))),
                          err_desc = "sits_cross_validate: invalid input bands")

     # check valid methods
     ensurer::ensure_that(method, (. == "gam" || . == "dendogram" || . == "centroids" || . == "kohonen" || . == "kohonen-dendogram"),
                          err_desc = "sits_patterns: valid methods are 'gam', 'dendogram', 'centroids', 'kohonen', or 'kohonen-dendogram'.")


     # recalculate kohonen params according to perc value
     if (method == "kohonen" || method == "kohonen-dendogram") {
          koh_xgrid = trunc(koh_xgrid * sqrt(perc))
          koh_ygrid = trunc(koh_ygrid * sqrt(perc))
          koh_rlen  = trunc(koh_rlen * sqrt(perc))
     }

     #extract the bands to be included in the patterns
     if (purrr::is_null (bands))
          bands <- sits_bands (data.tb)
     data.tb <- sits_select(data.tb, bands)

     # create partitions different splits of the input data
     partitions.lst <- .sits_create_partitions (data.tb, times, frac = perc)

     # for each partition, fill the prediction and reference vectors
     if (.multicores == 1)
          conf.lst  <- Map(.sits_classify_partitions,partitions.lst)
     else
          conf.lst <- parallel::mcMap(.sits_classify_partitions, partitions.lst, mc.cores = .multicores)

     pred.vec = character()
     ref.vec = character()
     purrr::map(conf.lst, function (e) {
               mid <- length (e)/2
               pred.vec <<- append (pred.vec, e[1:mid])
               ref.vec <<- append (ref.vec, e[(mid+1):length(e)])
          })
     confusion.vec <- c(pred.vec, ref.vec)
     # save the confusion vector in  a JSON file
     sits_toJSON (confusion.vec, file)

     # Classification accuracy measures
     assessment <- .sits_accuracy(pred.vec, ref.vec, pred_sans_ext = TRUE)

     return (assessment)
}
#' @title Create partitions of a data set
#' @name  sits_create_partitions
#' @author Rolf Simoes, \email{rolf.simoes@@inpe.br}
#'
#' @description Create a list of partitions of a SITS table, based on a percentage and
#' a number of iterations
#'
#' @param data.tb a SITS table to be partitioned
#' @param times   number of iterations
#' @param frac    fraction of original data to be extracted. Value must be between 0 and 1.
.sits_create_partitions <- function (data.tb, times, frac) {

     # create a list to store the partitions
     partitions.lst <- tibble::lst()

     # iterate and create the partitions
     for (i in 1:times){
          partitions.lst [[i]] <- sits_labels_sample (data.tb, frac)
     }
     return (partitions.lst)
}

#' @title reassess classification results
#' @name sits_reassess
#' @author Victor Maus, \email{vwmaus1@@gmail.com}
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#' @author Rolf Simoes, \email{rolf.simoes@@inpe.br}
#'
#' @description Given a confusion matrix obtained in the validation
#' procedure, and a conversion list between the original labels and
#' new labels, returns a new confusion matrix
#' where classes have been merged.
#'
#' @param  file           a JSON file contaning the result of a validation procedure
#' @param  conv           a conversion of label names for the classes (optional))
#' @return assess         an assessment of validation
#' @export
sits_reassess <- function (file = NULL, conv = NULL){
     ensurer::ensure_that(file, !purrr::is_null(.),
                          err_desc = "sits_relabel: JSON file not provided")

     # return the confusion matrix
     confusion.vec <- jsonlite::fromJSON (file)
     mid <- length(confusion.vec)/2
     pred.vec <- confusion.vec[1:mid]
     ref.vec  <- confusion.vec[(mid+1):length(confusion.vec)]

     # calculate the accuracy assessment
     assess <- .sits_accuracy(pred.vec, ref.vec, pred_sans_ext = TRUE, conv.lst = conv)

     return (assess)
}

#' @title Evaluates the accuracy of a set of patterns
#' @name sits_test_patterns
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#
#' @description Tests the accuracy of TWDTW classification
#' of set of labelled samples using a set of patterns.
#' This function should be used when the patterns are not directly derived from the samples.
#' It provides an initial assessment of the validity of using this set of pattern
#' to classify an area whose samples are given.
#' This function returns the Overall Accuracy, User's Accuracy,
#' Producer's Accuracy, error matrix (confusion matrix), and Kappa values.
#'
#' @param  data.tb       A sits tibble containing a set of samples with known and trusted labels
#' @param  patterns.tb   A sits tibble containing a set of patterns
#' @param  bands         the bands used for classification
#' @param  alpha         (double)  - the steepness of the logistic function used for temporal weighting
#' @param  beta          (integer) - the midpoint (in days) of the logistic function
#' @param  theta         (double)  - the relative weight of the time distance compared to the dtw distance
#' @param  span          (integer) - minimum number of days between two matches of the same pattern in the time series (approximate)
#' @param  start_date    date - the start of the classification period
#' @param  end_date      date - the end of the classification period
#' @param  interval      date - the period between two classifications
#' @param  overlap       (double) minimum overlapping between one match and the interval of classification
#' @return assess         an assessment of validation
#' @export
sits_test_patterns <- function (data.tb, patterns.tb, bands,
                                alpha = -0.1, beta = 100, theta = 0.5, span  = 0,
                                start_date = NULL, end_date = NULL, interval = "12 month", overlap = 0.5) {

     ensurer::ensure_that (data.tb, !purrr::is_null(.),
                            err_desc = "sits_test_patterns: please provide a set of time series to test")
     ensurer::ensure_that (patterns.tb, !purrr::is_null(.),
                      err_desc = "sits_test_patterns: please provide a set of patterns to test")
     ensurer::ensure_that (bands, !purrr::is_null(.),
                           err_desc = "sits_test_patterns: please provide the bands to be used")
     ensurer::ensure_that (data.tb, !("NoClass" %in% sits_labels(.)$label),
                            err_desc = "sits_test_patterns: please provide a labelled set of time series")


     # classify data
     matches.tb  <- sits_TWDTW_matches (data.tb, patterns.tb, bands = bands, alpha = alpha, beta = beta, theta = theta, span = span)
     class.tb    <- sits_TWDTW_classify (matches.tb, start_date = start_date, end_date = end_date, interval = interval, overlap = overlap)

     # retrieve the reference labels
     ref.vec <- as.character(class.tb$label)
     # retrieve the predicted labels
     pred.vec  <- as.character(purrr::map(class.tb$best_matches, function (e) as.character(e$label)))

     # calculate the accuracy assessment
     assess <- .sits_accuracy(pred.vec, ref.vec, pred_sans_ext = TRUE)

     return (assess)
}

#' @title Evaluates the accuracy of classification
#' @name .sits_accuracy
#' @author Rolf Simoes, \email{rolf.simoes@@inpe.br}
#
#' @description Evaluates the accuracy of classification stored in two vectors.
#' Returns the overall accuracy, producers and users accuracy, and confusion matrix.
#' This algorith was inspired by `rfUtilities::accuracy` function, and fix the user and
#' producer accuracy computation inconsistency.
#'
#' @param pred.vec       A vector of all predicted labels.
#' @param ref.vec        A vector of all reference labels.
#' @param pred_sans_ext  (Boolean) remove all label extension (i.e. every string after last '.' character) from predictors before compute assesment.
#' @param conv.lst       A list conversion list of labels. If NULL no conversion is done.
#' @return result.lst     a list with accuracy measures and confusion matrix
.sits_accuracy <- function(pred.vec, ref.vec, pred_sans_ext = FALSE, conv.lst = NULL){

     # remove predicted labels' extensions
     if (pred_sans_ext)
          pred.vec <- tools::file_path_sans_ext(pred.vec)

     # count all pairs of labels
     # rows: predicted labels; cols: reference labels
     if (is.null(conv.lst))
          conf.mtx <- table(pred.vec, ref.vec)
     else{
          ensurer::ensure_that(c(pred.vec, ref.vec),
                               all(names(.) %in% names(conv.lst)),
                               err_desc = ".sits_accuracy: conversion list does not contain all labels provided in `pred.vec` and/or `ref.vec` arguments.")
          conf.mtx <- table(as.character(conv.lst[[pred.vec]]), as.character(conv.lst[[ref.vec]]))
     }

     # ensures that the confusion matrix is square
     ensurer::ensure_that(conf.mtx, NCOL(.) == NROW(.),
                          err_desc = ".sits_accuracy: predicted and reference vectors does not produce a squared matrix. Try to convert `pred.vec` entries before compute accuracy.")

     # sort rows (predicted labels) according to collumn names (reference labels)
     conf.mtx <- conf.mtx[colnames(conf.mtx),]

     # get labels' agreement (matrix diagonal)
     agreement <- diag(conf.mtx)

     # get total of predicted labels (to compute users accuracy)
     users <- apply(conf.mtx, 1, sum)

     # get total of reference labels (to compute producers accuracy)
     producers <- apply(conf.mtx, 2, sum)

     # get grand totals
     agreement_total <- sum(agreement)
     grand_total <- sum(conf.mtx)

     # compose result list
     result.lst <- tibble::lst(
          overall.accuracy = round(agreement_total / grand_total * 100, 4),
          producer.accuracy = round(agreement / producers * 100, 4),
          user.accuracy = round(agreement / users * 100, 4),
          confusion = conf.mtx
     )

     return(result.lst)
}
