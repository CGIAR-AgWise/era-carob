cache <- Sys.getenv("SF001_INPUTS", "downloaded_data/sf001")
one_input <- function(pattern) {
  f <- Sys.glob(file.path(cache,pattern))
  stopifnot(length(f)==1L)
  f
}
bindr <- function(...) as.data.frame(dplyr::bind_rows(...))
fix_name <- function(x,case="") {
  x <- trimws(gsub("[[:space:]]+"," ",x)); x[x==""] <- NA_character_
  if (case=="title") stringr::str_to_title(x) else x
}

crop_key <- function(x) tolower(trimws(gsub("[[:space:]]+", " ", x)))
current_crop_crosswalk <- function(master, labels) {
  aliases <- read.csv("script/crop_aliases.csv")
  spell <- function(x) {
    k <- crop_key(x)
    i <- match(k, aliases$alias)
    k[!is.na(i)] <- aliases$product[i[!is.na(i)]]
    k
  }
  p <- subset(master$prod, Product.Type=="Plant")
  products <- spell(p$Product.Simple)
  valid <- !is.na(products) & nzchar(products) &
    !grepl("unspecified|unknown|fallow|natural vegetation", products)
  terms <- do.call(rbind, lapply(c("Product","Product.Simple","Latin.Name"), function(field) {
    data.frame(key=spell(p[[field]][valid]), product=products[valid])
  }))
  terms <- unique(subset(terms, !is.na(key) & !key %in% c("","na","no match")))
  ambiguous <- duplicated(terms$key) | duplicated(terms$key, fromLast=TRUE)
  terms <- terms[!ambiguous,]
  keys <- sort(unique(crop_key(labels)),method="radix")
  data.frame("raw label"=keys,"resolved product"=terms$product[match(spell(keys),terms$key)],
             check.names=FALSE)
}

season_planting_date <- function(raw, season) {
  day_text <- as.character(raw)
  year <- ifelse(grepl("^[0-9]{4}([.][0-9]+)?$", season), substr(season,1,4), NA_character_)
  parsed <- as.Date(day_text,format="%Y-%m-%d")
  valid <- !is.na(parsed) & !is.na(year) &
    format(parsed,"%Y-%m-%d")==day_text & format(parsed,"%Y")==year
  day_text[is.na(valid) | !valid] <- NA_character_
  day_text
}
