% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/design-matrix.r
\name{meffil.design.matrix}
\alias{meffil.design.matrix}
\title{Infinium HumanMethylation450 BeadChip normalization design matrix}
\usage{
meffil.design.matrix(
  qc.objects,
  number.pcs,
  fixed.effects = NULL,
  random.effects = NULL
)
}
\arguments{
\item{qc.objects}{A list of outputs from \code{\link{meffil.create.qc.object}()}.}

\item{number.pcs}{Number of principal components to include in the design matrix (Default: all).}

\item{fixed.effects}{Names of columns in samplesheet that should be included as fixed effects
along with control matrix principal components (Default: NULL).}

\item{random.effects}{Names of columns in samplesheet that should be included as random effects
(Default: NULL).}
}
\value{
Design matrix with one column for each of the first \code{number.pcs} prinicipal
components.
}
\description{
Design matrix derived by applying principal components analysis to control probes.
}
