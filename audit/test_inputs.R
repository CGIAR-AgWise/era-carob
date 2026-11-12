source("script/pinned.R")
master <- list(prod=data.frame(Product.Type="Plant",Product="Example grain",
                               Product.Simple="Small grain",Latin.Name="Example species"))
x <- current_crop_crosswalk(master,c(" Example   grain ","Example species","Example grain-Maize"))
stopifnot(identical(x[["resolved product"]][match(c("example grain","example species","example grain-maize"),x[["raw label"]])],
                    c("small grain","small grain",NA_character_)))
stopifnot(identical(season_planting_date(c("2014-06-02","2084-06-02","2014-02-30","2014-06"),
                                         c("2014.2","2014","2014","2014")),
                    c("2014-06-02",rep(NA_character_,3))))
cat("New crop vocabulary and corrected source date checks passed.\n")
