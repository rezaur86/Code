source('~/scripts/cascade/tools.r')
source('~/scripts/cascade/plfit.r')
library('MASS')
library('distr')
library(plyr)

branching_process <- function(outdeg_dist, trial=0, max_generation){
	generation_population <- c()
	random_outdeg_chooser <- function(dist) {
		return(sample(x=dist$outdeg, size=1, prob=(dist$count/sum(dist$count))))
	}
	population_outreached <- function(){
		population <- sum(generation_population)+1
		if (population%%100000==0)
			print(population)
		if (population > 189989307)
			return (TRUE)
		else
			return (FALSE)
	}
	manage_generation_population <- function(generation, population){
		if (length(generation_population) >= generation)
			generation_population[generation] <<- generation_population[generation] + population
		else
			generation_population <<- c(generation_population, population)
	}
	branching <- function(dist, generation, max_generation){
		if(generation > 60){ #We don't care any population in later generations
		}
		else{
			if (generation < max_generation)
				outdeg <- random_outdeg_chooser(dist[[generation+1]])
			else
				outdeg <- random_outdeg_chooser(dist[[max_generation+1]])
			if(generation > 0)
				manage_generation_population(generation, 1)
			if (outdeg>0 & population_outreached()==FALSE){
				for (each_branch in 1:outdeg){	
					branching(dist, generation+1, max_generation)
				}
			}
		}
	}
	cascades <- list(size=c(),depth=c(),growth=vector("list"))
	for (i in 1:trial){
		print_report('Trial #',i)
		generation_population <- c()
		branching(outdeg_dist, 0, max_generation)
		cascades$size <- c(cascades$size, sum(generation_population)+1)
		cascades$depth <- c(cascades$depth, length(generation_population))
		cascades$growth[[i]] <- generation_population
		print(sum(generation_population)+1)
	}
	return(cascades)
}

analyze_outdeg_dist <- function(binned_dist){
	plot <- ggplot(data=binned_dist, aes(x = log10(outdeg), y = log10(count/sum(count)))) + geom_line(aes(group = 'Type', colour = 'Bin out degree')) + xlab('log of Out degree') + ylab('log of proportion of Count')
	unrolled_bin_odeg <- rep(binned_dist$outdeg, times = binned_dist$count)
	plfit_param <- plfit(unrolled_bin_odeg[unrolled_bin_odeg>0])
	plaw.df <<- data.frame(outdeg=binned_dist[binned_dist$outdeg>=plfit_param$xmin,]$outdeg, alpha=plfit_param$alpha, const=plfit_param$xmin)#/sum(binned_dist[binned_dist$outdeg>0,]$count))*sum(binned_dist$count))
	plot <- plot + geom_line(data=plaw.df, aes(log10(outdeg), log10(const*(outdeg^-alpha)), colour='power-law'),linetype="dashed")
	t2<<-data.frame(x=2, y=-0.5, l2=paste("gamma=",round(plfit_param$alpha,4)))
	plot <- plot + geom_text(data=t2, aes(x, y, label=l2),color = "grey50", size = 4)
	plot <- plot + geom_line(data=raw_outdeg, aes(log10(outdeg), log10(count/sum(count)), colour='Raw out degree'))
	unrolled_raw_odeg <- rep(raw_outdeg$outdeg, times=raw_outdeg$count)
	fitted_estimate <- fitdistr(unrolled_raw_odeg[unrolled_raw_odeg>0],'log-normal')
	print(fitted_estimate)
	fitted_lnorm_values <- c()
	fitted_lnorm_values$outdeg <- raw_outdeg[raw_outdeg$outdeg>0 & raw_outdeg$outdeg<10000,]$outdeg
	fitted_lnorm_values$count <- raw_outdeg[raw_outdeg$outdeg>0 & raw_outdeg$outdeg<10000,]$count
	fitted_lnorm_values$density <- (sum(fitted_lnorm_values$count)/sum(raw_outdeg$count))*(dlnorm(fitted_lnorm_values$outdeg, meanlog=fitted_estimate$estimate[1],sdlog=fitted_estimate$estimate[2]))
	fitted_lnorm_values <- as.data.frame(fitted_lnorm_values)
	plot <- plot + geom_line(data=fitted_lnorm_values, aes(log10(outdeg), log10(density), colour='log-normal'),linetype="dashed")
	t1<<-data.frame(x=2, y=0, l1=paste("lnN(.,.)=(",round(exp(fitted_estimate$estimate[1]),4),",",round(exp(fitted_estimate$estimate[2]),4),")"))
	plot <- plot + geom_text(data=t1, aes(x, y, label=l1),color = "grey50", size = 4)
	save_ggplot(plot, paste(c(output_dir,bin_size[i],'outdeg_dist.pdf'), collapse = ''))
}

analyze_branching <- function(output_dir, trial, bin_size){
	max_depth <- max(g_prep.df$outdeg_dist$depth)
	dist_bin <- list()
	bin_outdeg_dist <- c()
	root_outdeg <- g_prep.df$outdeg_dist[(g_prep.df$outdeg_dist$depth==0),]
#	dist_bin[[1]] <- ddply(root_outdeg, c('outdeg'), summarise, count=sum(count))
#	bin_size <- c(1,2,3,4,5,21,36,61) #seq(1,max_depth, by=bin_size)
#	bin_size <- c(1,11,21,31,41,51,61)
	for (i in 1:(length(bin_size)-1)){
		binned_data <- g_prep.df$outdeg_dist[(g_prep.df$outdeg_dist$depth>=bin_size[i] & g_prep.df$outdeg_dist$depth<bin_size[i+1]),]
		binned_dist <<- ddply(binned_data, c('outdeg'), summarise, count=sum(count))
#		analyze_outdeg_dist(binned_dist)
		bin_outdeg_dist <- rbind(bin_outdeg_dist,cbind(binned_dist,rep(bin_size[i],nrow(binned_dist))))
		for (j in bin_size[i]:min(bin_size[i+1],max_depth)){
			dist_bin[[j+1]] <- binned_dist
		}
	}
	colnames(bin_outdeg_dist) <- c('outdeg', 'count', 'depth')
	bin_outdeg_dist.df <- ddply (bin_outdeg_dist,  c('depth'), function (one_partition){
				one_partition$pdf = one_partition$count/sum(one_partition$count)
				one_partition
			})
	bin_outdeg_dist.df$depth <- factor(bin_outdeg_dist.df$depth)
	plot <- ggplot(bin_outdeg_dist.df, aes(x = log10(outdeg), y = log10(pdf))) + geom_line(aes(group = depth,colour = depth)) + xlab('Out degree') + ylab('log of proportion of Count')
	save_ggplot(plot, paste(c(output_dir,'outdeg_dist.pdf'), collapse = ''))
#	print_report('P(0 out degree)',nonroot_deg_dist$count[1]/sum(nonroot_deg_dist$count))
#	expected_root_odeg <- sum(root_deg_dist$outdeg*(root_deg_dist$count/sum(root_deg_dist$count)))
#	expected_nonroot_odeg <- sum(nonroot_deg_dist$outdeg*(nonroot_deg_dist$count/sum(nonroot_deg_dist$count)))
#	print_report('expected root degree', expected_root_odeg)
#	print_report('expected nonroot degree', expected_nonroot_odeg)
	options(expressions = 10000)
	simulated_cascades <- branching_process(dist_bin,trial,max_depth)
	return(simulated_cascades)
}
#ab_10 <- analyze_branching('~/output_cascade/fp_nt_u/bin_10/',4,bin_size <- c(0,10,20,30,40,50,60))
#ab_v <- analyze_branching('~/output_cascade/fp_nt_u/bin_v/',4,bin_size <- c(0,1,2,3,4,5,21,36,61))
#ab_e <- analyze_branching('~/output_cascade/fp_nt_u/bin_e/',4,bin_size <- c(0,2,4,8,16,32,64))
#ab_1 <- analyze_branching('~/output_cascade/fp_nt_u/bin_1/',1,bin_size <- c(0:60))
#print_report('Summary size', summary(ab_10$size))
#print_report('Summary depth', summary(ab_10$depth))
#ab_5 <- analyze_branching('~/output_cascade/full_first_parent/top_size.csv_top_1000_branching_dist.csv',5)
#print_report('Summary size', summary(ab_5$size))
#print_report('Summary depth', summary(ab_5$depth))
#ab_1 <- analyze_branching('~/output_cascade/full_first_parent/top_size.csv_top_1000_branching_dist.csv',1)
#print_report('Summary size', summary(ab_1$size))
#print_report('Summary depth', summary(ab_1$depth))
#
#idx <- c(1:length(ab_10$size))
#sorted_idx <- idx[order(-ab_10$size)]
#ab_10.df <- data.frame(depth=0:length(ab_10$growth[[sorted_idx[1]]]), shell=c(1,ab_10$growth[[sorted_idx[1]]]), tree=rep(1, times=length(ab_10$growth[[sorted_idx[1]]])+1))
#for (i in 2:30){
#	data_f <- data.frame(depth=0:length(ab_10$growth[[sorted_idx[i]]]), shell=c(1,ab_10$growth[[sorted_idx[i]]]), tree=rep(i, times=length(ab_10$growth[[sorted_idx[i]]])+1))
#	ab_10.df <- rbind(ab_10.df,data_f)
#}
#ab_10.df$tree <- factor(ab_10.df$tree)
#plot <- ggplot(ab_10.df, aes(x = depth, y = (shell))) + geom_line(aes(group = tree,colour = tree)) + xlab('Depth') + ylab('Shell size') 
#save_ggplot(plot, paste('~/output_cascade/full_first_parent/branching_bin_10.pdf', collapse = ''))
#
#idx <- c(1:length(ab_5$size))
#sorted_idx <- idx[order(-ab_5$size)]
#ab_5.df <- data.frame(depth=0:length(ab_5$growth[[sorted_idx[1]]]), shell=c(1,ab_5$growth[[sorted_idx[1]]]), tree=rep(1, times=length(ab_5$growth[[sorted_idx[1]]])+1))
#for (i in 2:30){
#	data_f <- data.frame(depth=0:length(ab_5$growth[[sorted_idx[i]]]), shell=c(1,ab_5$growth[[sorted_idx[i]]]), tree=rep(i, times=length(ab_5$growth[[sorted_idx[i]]])+1))
#	ab_5.df <- rbind(ab_5.df,data_f)
#}
#ab_5.df$tree <- factor(ab_5.df$tree)
#plot <- ggplot(ab_5.df, aes(x = depth, y = (shell))) + geom_line(aes(group = tree,colour = tree)) + xlab('Depth') + ylab('Shell size') 
#save_ggplot(plot, paste('~/output_cascade/full_first_parent/branching_bin_5.pdf', collapse = ''))
#
#idx <- c(1:length(ab_1$size))
#sorted_idx <- idx[order(-ab_1$size)]
#ab_1.df <- data.frame(depth=0:length(ab_1$growth[[sorted_idx[1]]]), shell=c(1,ab_1$growth[[sorted_idx[1]]]), tree=rep(1, times=length(ab_1$growth[[sorted_idx[1]]])+1))
#for (i in 2:30){
#	data_f <- data.frame(depth=0:length(ab_1$growth[[sorted_idx[i]]]), shell=c(1,ab_1$growth[[sorted_idx[i]]]), tree=rep(i, times=length(ab_1$growth[[sorted_idx[i]]])+1))
#	ab_1.df <- rbind(ab_1.df,data_f)
#}
#ab_1.df$tree <- factor(ab_1.df$tree)
#plot <- ggplot(ab_1.df, aes(x = depth, y = (shell))) + geom_line(aes(group = tree,colour = tree)) + xlab('Depth') + ylab('Shell size') 
#save_ggplot(plot, paste('~/output_cascade/full_first_parent/branching_bin_1.pdf', collapse = ''))
