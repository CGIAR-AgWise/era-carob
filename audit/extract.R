cache <- normalizePath(commandArgs(TRUE)[1],mustWork=TRUE)
d <- readRDS(file.path(cache,"june.rds"))
write.csv(d[c("dataset_id","crop","country","uri")],file.path(cache,"historical_era.csv"),row.names=FALSE,na="")
