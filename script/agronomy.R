# Numeric fields have explicit target units. Unknown, compound and unsupported
# units retain their source value in the ERA evidence fields.
convert_measure <- function(value, unit, factors) {
  number <- suppressWarnings(as.numeric(as.character(value)))
  number[!is.finite(number) | number < 0] <- NA_real_
  number * unname(factors[trimws(as.character(unit))])
}

mass_area <- c("kg/ha"=1, "Mg/ha"=1000, "t/ha"=1000, "g/m2"=10)
percent_mass <- c("%"=1, "% (w/w)"=1, "g/kg"=.1, "g C/kg"=.1,
                  "mg/g"=.1, "mg C/g"=.1, "mg/kg"=.0001)
nitrogen_mgkg <- c("mg/kg"=1, "mg N/kg"=1, "g/kg"=1000, "mg/g"=1000,
                   "mg N/g"=1000, "ug N/g"=1, "%"=10000, "% (w/w)"=10000)
carbon_stock <- c("Mg/ha"=1, "Mg C/ha"=1, "t/ha"=1, "kg/ha"=.001, "kg/m2"=10)

map_site_measure <- function(variable, value, unit) {
  rules <- list(CLY=percent_mass, SLT=percent_mass, SND=percent_mass,
                Soil.TP=nitrogen_mgkg[c("mg/kg","g/kg","%")],
                Soil.EC=c("mS/cm"=1,"dS/m"=1,"Ds/m"=1,"mS/m"=.01),
                Soil.BD=c("g/cm3"=1,"Mg/m3"=1,"t/m3"=1,"kg/dm3"=1))
  out <- rep(NA_real_, length(value))
  for (key in names(rules)) {
    i <- which(variable == key)
    out[i] <- convert_measure(value[i],unit[i],rules[[key]])
  }
  ph <- which(variable=="Soil.pH" & is.finite(value) & value>=0 & value<=14)
  out[ph] <- value[ph]
  out
}

irrigation_flag <- function(amount, method, level) {
  n <- suppressWarnings(as.numeric(as.character(amount)))
  positive_method <- method %in% c("Drip (b34)", "Drip Irrigation", "Flood (Complete)",
      "Flood (Furrow)", "Sprinkler Irrigation", "Sprinkler (b72)", "Irrigation (Other)",
      "Alternate Partial Rootzone Irrigation")
  yes <- positive_method | (is.finite(n) & n>0)
  no <- tolower(trimws(level)) %in% c("rainfed","rain-fed","no irrigation") |
    (is.finite(n) & n==0)
  ifelse(yes & !no, TRUE, ifelse(no & !yes, FALSE, NA))
}

map_harvest_part <- function(raw) {
  # Match a whole label after removing exactly one parenthesised yield qualifier.
  # Combined Tuber/Root is ambiguous, as are corms for a roots/tubers split.
  label <- sub(" \\((Unspecified|Total Yield|Marketable Yield|Non-Marketable Yield)\\)$","",raw)
  parts <- c("Grain/Seed"="grain","Pods"="pod","Fruit"="fruit","Leaves"="leaves",
      "Stalks"="stems","Stem/Stalks"="stems","Wood - Timber"="wood",
      "Biomass/Fodder - Above Ground"="aboveground biomass")
  unname(parts[label])
}

whole_reps <- function(x) {
  x <- as.character(x)
  ifelse(grepl("^[1-9][0-9]*$", x), suppressWarnings(as.integer(x)), NA_integer_)
}

fertilizer_rate <- function(element, unit, oxide=NULL, element_fraction=1) {
  val <- as.character(element)
  val[val %in% c("999","999999")] <- NA_character_
  rate <- convert_measure(val,unit,mass_area)
  if (!is.null(oxide)) {
    absent <- is.na(element) | trimws(element) %in% c("","NA")
    ox <- as.character(oxide)
    ox[ox %in% c("999","999999")] <- NA_character_
    rate[absent] <- convert_measure(ox[absent],unit[absent],mass_area)*element_fraction
  }
  rate
}
