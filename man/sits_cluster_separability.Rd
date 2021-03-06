% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_separability.R
\name{sits_cluster_separability}
\alias{sits_cluster_separability}
\title{compare clusters against original labels and computes a separability matrix.}
\usage{
sits_cluster_separability(data.tb)
}
\arguments{
\item{data.tb}{a SITS table with the samples to be validated}
}
\value{
result.tb      a tibble with separability matrix.
}
\description{
Given a sits table with `original_label` column, computes a separability matrix
between the original labels (`original_label` column) and new labels. This is useful
to analyse the separability of samples for a given clustering algorithm.
}
\author{
Rolf Simoes, \email{rolf.simoes@inpe.br}
}
