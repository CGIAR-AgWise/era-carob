# Compare complete candidates; no climate extraction or source-date inference.
args <- commandArgs(TRUE)
if (length(args)!=2L) stop("Usage: Rscript audit/check_date_successor.R historical.rds issue94.rds")
a <- readRDS(args[1]); b <- readRDS(args[2])
stopifnot(identical(names(a),names(b)),identical(a$source,b$source),
          identical(a$source_row,b$source_row),nrow(a)==nrow(b))
dates <- c("planting_date","planting_date_raw","transplanting_date","harvest_date")
carob <- a$source=="carob"
for (field in names(a)) {
  stopifnot(identical(a[[field]][carob],b[[field]][carob]))
  if (!field %in% dates) stopifnot(identical(a[[field]],b[[field]]))
}
changed <- vapply(dates,function(field) {
  x <- as.character(a[[field]]); y <- as.character(b[[field]])
  sum(is.na(x)!=is.na(y) | (!is.na(x)&!is.na(y)&x!=y))
},integer(1))
stopifnot(identical(unname(changed),c(40655L,70161L,2734L,22235L)))
print(changed)
cat("Date-only successor: all source keys, Carob cells and non-date values unchanged.\n")
