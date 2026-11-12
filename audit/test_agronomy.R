# Scientific checks cover dimensional differences and conflicting evidence.
source("script/agronomy.R")
stopifnot(
  identical(convert_measure(c(2,10,2),c("Mg/ha","g/m2","g/plant"),mass_area),c(2000,100,NA_real_)),
  identical(convert_measure(c(10,2),c("g/kg","Mg/ha"),percent_mass),c(1,NA_real_)),
  identical(convert_measure(c(10,2),c("g/kg","Mg/ha"),carbon_stock),c(NA_real_,2)),
  identical(map_harvest_part(c("Grain/Seed","Corm (Unspecified)")),c("grain",NA_character_)),
  identical(irrigation_flag(c(NA,NA,0,0),c("Drip (b34)",NA,NA,"Drip (b34)"),
                            c(NA,NA,"Rainfed",NA)),c(TRUE,NA,FALSE,NA)),
  identical(whole_reps(c("3","3...4","Not in template")),c(3L,NA_integer_,NA_integer_)),
  isTRUE(all.equal(fertilizer_rate(c(NA,10,10),c("kg/ha","kg/ha","g/plant"),
                                   c(100,100,100),0.4364),c(43.64,10,NA_real_)))
)
