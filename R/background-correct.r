# Background correction
#
# Background correct Cy5/Cy3 signal of a Infinium HumanMethylation450 BeadChip.
#
# @param rg Cy5/Cy3 signal generated by \code{\link{read.rg}()}.
# @param offset Number to add to background corrected signal (Default: 15).
# @param verbose If \code{TRUE}, then status messages are printed during execution (Default: \code{FALSE}).
# @return Background corrected Cy5/Cy3 signal by \code{\link[limma]{normexp.signal}}.
background.correct <- function(rg, probes, offset=15, verbose=F) {
    stopifnot(is.rg(rg))
    
    for (dye in c("R","G")) {
        msg("background correction for dye =", dye, verbose=verbose)
        addresses <- probes$address[which(probes$target %in% c("M","U") & probes$dye == dye)]
        addresses <- intersect(addresses, rownames(rg[[dye]]))
        if(length(addresses) == 0)
            stop("It seems like the supplied chip annotation does not match the IDAT files.")
        xf <- rg[[dye]][addresses,"Mean"]
        xf[which(xf <= 0)] <- 1

        addresses <- probes$address[which(probes$type == "control" & probes$dye == dye)]
        addresses <- intersect(addresses, rownames(rg[[dye]]))
        if(length(addresses) == 0)
            stop("It seems like the supplied chip annotation does not match the IDAT files.")
        xc <- rg[[dye]][addresses,"Mean"]
        xc[which(xc <= 0)] <- 1

        addresses <- probes$address[which(probes$target == "OOB" & probes$dye == dye)]
        addresses <- intersect(addresses, rownames(rg[[dye]]))
        if(length(addresses) == 0)
            stop("It seems like the supplied chip annotation does not match the IDAT files.")
        oob <- rg[[dye]][addresses,"Mean"]

        bg <- rep(NA, length(xf) + length(xc))
        try({
            ests <- huber.2(oob)
            mu <- ests$mu
            sigma <- log(ests$s)
            alpha <- log(max(huber.2(xf)$mu - mu, 10))
            ## mu = robust median of the oob probes
            ## sigma = log(mad of the oob probes)
            ## alpha = log(robust median of meth/unmeth probes  -  robust median of oob probes)
            ## c(xf,xc) = c(meth/unmeth probes, control probes)
            ## bg <- c(xf,xc) background corrected
            bg <- limma::normexp.signal(as.numeric(c(mu,sigma,alpha)), c(xf,xc)) + offset
        })
        rg[[dye]][c(names(xf), names(xc)), "Mean"] <- bg
        
    }
    rg
}

huber.2 <- function(x) {
    ret <- tryCatch(MASS::huber(x), error=function(e) e)
    if ("error" %in% class(ret)) 
        ret <- MASS::huber(x[which(x > min(x,na.rm=T))])
    ret
}
