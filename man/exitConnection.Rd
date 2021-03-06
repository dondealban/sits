% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_SCIDB.R
\name{exitConnection}
\alias{exitConnection}
\title{Exit a connection from SciDB chunk processing.}
\usage{
exitConnection(out, connection)
}
\arguments{
\item{out}{list or data.frame with classification data to return to SciDB}

\item{connection}{connection object to flush}
}
\description{
This function closes a SciDB streaming processing connection
}
