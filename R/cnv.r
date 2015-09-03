# library(CopyNumber450k)
# library(CopyNumber450kData)
# library(plyr)
# library(meffil)
# library(splitstackshape)


map_cnvs <- function(segments)
{
	probenames <- meffil.get.sites()
	probeinfo <- subset(meffil.probe.info(), name %in% probenames & target == "M", select=c(name, chr, pos))
	segments$loc.start <- as.numeric(segments$loc.start)
	segments$loc.end <- as.numeric(segments$loc.end)
	segments$seg.mean <- as.numeric(segments$seg.mean)
	segments$num.mark <- as.numeric(segments$num.mark)
	segments$adjusted.pvalue <- as.numeric(segments$adjusted.pvalue)
	gene <- cSplit(indt=segments, splitCols="genes", sep=";", direction="long")
	gene <- gene[order(gene$genes, gene$adjusted.pvalue), ]
	gene <- subset(gene[order(gene$genes, gene$adjusted.pvalue), ], !duplicated(genes), select=c(genes, seg.mean, num.mark, adjusted.pvalue))
	res <- ddply(segments, .(chrom, loc.start), function(x)
	{
		p <- subset(probeinfo, chr == x$chrom[1] & pos >= x$loc.start[1] & pos <= x$loc.end[1])
		p$seg.mean <- x$seg.mean[1]
		p$num.mark <- x$num.mark[1]
		p$adjusted.pvalue <- x$adjusted.pvalue[1]
		return(p)
	})
	p <- subset(probeinfo, select=c(name))
	p <- merge(p, subset(res, select=c(name, seg.mean, num.mark, adjusted.pvalue)), by="name", all.x=TRUE)
	return(list(cpg=p, gene=gene))
}


read.mu <- function(basename, verbose=F) {
  rg <- read.rg(basename, verbose=verbose)
  rg.to.mu(rg)
}

mu.to.cn <- function(mu) {
  mu$M + mu$U
}

read.cn <- function(basename, verbose=F) {
  mu <- read.mu(basename, verbose=verbose)
  mu.to.cn(mu)
}

predict.sex <- function(cn, sex.cutoff=-2) {
    probes <- meffil.probe.info()
  probes.x <- meffil.get.x.sites()
  x.signal <- median(cn[probes.x], na.rm=T)
  probes.y <- meffil.get.y.sites()
  y.signal <- median(cn[probes.y], na.rm=T)
   xy.diff <- y.signal-x.signal
   ifelse(xy.diff < sex.cutoff, "F", "M")
}
  

get_cnv_controls <- function(verbose=FALSE)
{
	require(CopyNumber450kData)
	data(RGcontrolSetEx)
	x <- preprocessRaw(RGcontrolSetEx)
	x <- getMeth(x) + getUnmeth(x)

	msg("Predicting sex", verbose=verbose)
	s <- apply(log2(x), 2, predict.sex)

	# Quantile normalize controls

	msg("Performing quantile normalisation", verbose=verbose)
	probes.sex <- c(meffil.get.x.sites(), meffil.get.y.sites())
	probes.aut <- meffil.get.autosomal.sites()

	int_sex_m <- x[probes.sex,s=="M"]
	int_sex_f <- x[probes.sex,s=="F"]
	int_aut <- x[probes.aut,]

	nom_sex_m <- list(rownames(int_sex_m), colnames(int_sex_m))
	nom_sex_f <- list(rownames(int_sex_f), colnames(int_sex_f))
	nom_aut <- list(rownames(int_aut), colnames(int_aut))

	int_sex_m <- preprocessCore::normalize.quantiles(int_sex_m)
	int_sex_f <- preprocessCore::normalize.quantiles(int_sex_f)
	int_aut <- preprocessCore::normalize.quantiles(int_aut)

	rownames(int_sex_m) <- nom_sex_m[[1]]
	colnames(int_sex_m) <- nom_sex_m[[2]]
	rownames(int_sex_f) <- nom_sex_f[[1]]
	colnames(int_sex_f) <- nom_sex_f[[2]]
	rownames(int_aut) <- nom_aut[[1]]
	colnames(int_aut) <- nom_aut[[2]]

	# Get medians for controls

	msg("Calculating control medians", verbose=verbose)
	control_medians_sex_m <- apply(int_sex_m, 1, median, na.rm=T)
	control_medians_sex_f <- apply(int_sex_f, 1, median, na.rm=T)
	control_medians_aut <- apply(int_aut, 1, median, na.rm=T)

	return(list(
		intensity_sex=list(M=int_sex_m, F=int_sex_f), 
		intensity_aut=int_aut, 
		sex=s, 
		control_medians_sex=list(M=control_medians_sex_m, F=control_medians_sex_f),
		control_medians_aut=control_medians_aut
	))
}


quantile_normalize_from_reference <- function(x, ref)
{
	quan <- sort(ref[,1])
	ord <- order(x)
	x[ord] <- quan
	return(x)
}


meffil_calculate_cnv <- function(bname, samplename=basename(bname), controls, trim=0.1, min.width = 5, nperm = 10000, alpha = 0.01, undo.splits = "sdundo", undo.SD = 2, verbose = TRUE)
{
	require(DNAcopy)
	msg("Reading idat file for", bname, verbose=verbose)
	case <- read.cn(bname)
	msg("Predicting sex", verbose=verbose)
	sex <- predict.sex(log2(case))

	msg("Normalisting against controls", verbose=verbose)
	probes.sex <- c(meffil.get.x.sites(), meffil.get.y.sites())
	probes.aut <- meffil.get.autosomal.sites()

	int_sex <- quantile_normalize_from_reference(case[probes.sex], controls$intensity_sex[[sex]])
	int_aut <- quantile_normalize_from_reference(case[probes.aut], controls$intensity_aut)

	msg("Estimating CNVs", verbose=verbose)
	int_sex <- log2(int_sex / controls$control_medians_sex[[sex]])
	int_aut <- log2(int_aut / controls$control_medians_aut)

	probes <- meffil.probe.info()
	probes$chr <- ordered(probes$chr, levels = c(paste("chr", 1:22, sep = ""), "chrX", "chrY"))
	p_sex <- probes[match(names(int_sex), probes$name), c("name", "chr","pos")]
	p_aut <- probes[match(names(int_aut), probes$name), c("name", "chr","pos")]

	cna_sex <- CNA(int_sex, chrom=p_sex$chr, maploc=p_sex$pos, data.type="logratio", sampleid=samplename)
	cna_aut <- CNA(int_aut, chrom=p_aut$chr, maploc=p_aut$pos, data.type="logratio", sampleid=samplename)

	smoothed_cna_sex <- smooth.CNA(cna_sex, trim)
	smoothed_cna_aut <- smooth.CNA(cna_aut, trim)

	segment_smoothed_cna_sex <- segment(cna_sex, min.width=min.width, verbose = verbose, nperm = nperm, alpha = alpha, undo.splits = undo.splits, undo.SD = undo.SD, trim = trim)
	segment_smoothed_cna_aut <- segment(cna_aut, min.width=min.width, verbose = verbose, nperm = nperm, alpha = alpha, undo.splits = undo.splits, undo.SD = undo.SD, trim = trim)
	out <- rbind(segment_smoothed_cna_aut$output, segment_smoothed_cna_sex$output)
	return(out)
}

