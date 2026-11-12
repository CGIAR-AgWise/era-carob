# Exploratory broad-schema conversion. Run audit/prepare.py first.
library(dplyr)
library(tidyr)
source("script/pinned.R")
era_merge <- jsonlite::fromJSON(one_input("agronomic_*.json"))
era_master <- jsonlite::fromJSON(one_input("era_master_codes*.json"))
# Source ordinal is stable only within the pinned ERA archive.
era_merge$Data.Out$era_source_row <- seq_len(nrow(era_merge$Data.Out))
# Retain every outcome once; ambiguous or incomplete lookup keys supply no attributes.
safe_lookup <- function(x,y,by) {
  y <- unique(as.data.frame(y))
  eligible <- complete.cases(y[by])
  y <- y[eligible & !duplicated(y[by]) & !duplicated(y[by], fromLast=TRUE),,drop=FALSE]
  z <- left_join(x,y,by=by,na_matches="never",relationship="many-to-one")
  stopifnot(identical(x$era_source_row,z$era_source_row))
  z
}
### Baseline data 
rb <-  do.call(bindr, era_merge["Data.Out"])

#### adding missing variables from prod.out to Data.out
r5 <- do.call(bindr, era_merge["Prod.Out"])
rb <- safe_lookup(rb, r5, by=intersect(names(rb), names(r5)))

### Adding Tillage variables from Till.out to Data.out
r7 <- do.call(bindr, era_merge["Till.Out"])
rb <- safe_lookup(rb, r7, by=intersect(names(rb), names(r7)))

### Adding planting management information 
r9 <- do.call(bindr, era_merge["Plant.Method"])
rb <- safe_lookup(rb, r9, by=intersect(names(rb), names(r9)))

### Adding fertilizer method
r12 <- do.call(bindr, era_merge["Fert.Method"])
rb <- safe_lookup(rb, r12, by=intersect(names(rb), names(r12)))

### Adding chemical elements 
r15 <- do.call(bindr, era_merge["Chems.Out"])
rb <- safe_lookup(rb, r15, by=intersect(names(rb), names(r15)))

#### residue 
r18 <-  unclass(do.call(bindr, era_merge["Res.Method"]) )
rb <- safe_lookup(rb, r18, by=intersect(names(rb), names(r18)))

## residue composition 
r19 <-  do.call(bindr, era_merge["Res.Comp"])
rb <- safe_lookup(rb, r19, by=intersect(names(rb), names(r19)))

#### 
r21 <-  do.call(bindr, era_merge["pH.Out"])
rb <- safe_lookup(rb, r21, by=intersect(names(rb), names(r21)))

####
r22 <-  do.call(bindr, era_merge["pH.Method"])
rb <- safe_lookup(rb, r22, by=intersect(names(rb), names(r22)))

##### irrigation
r23 <-  do.call(bindr, era_merge["Irrig.Method"])
rb <- safe_lookup(rb, r23, by=intersect(names(rb), names(r23)))

###
r25 <-  do.call(bindr, era_merge["WH.Out"])
rb <- safe_lookup(rb, r25, by=intersect(names(rb), names(r25)))

### Add soil data 
r2 <- do.call(bindr, era_merge["Soil.Out"])
d1 <- data.frame(
   Site.ID= r2$Site.ID,
   soil_depth= paste0(r2$Soil.Upper, "-", r2$Soil.Lower),
   B.Code= r2$B.Code,
   variable= r2$variable,
   value= r2$value
)

# Only one distinct value per measured variable at the same site and depth.
ds <- d1 %>% distinct() %>% group_by(B.Code, Site.ID, soil_depth, variable) %>%
   summarise(value=if(n()==1L) first(value) else NA_real_,.groups="drop") %>%
   pivot_wider(names_from=variable,values_from=value)
names(ds) <- sub("^Soil[.]","soil_",names(ds))
ds <- rename(ds,soil_clay=CLY,soil_silt=SLT,soil_sand=SND,soil_P=soil_AP)
rb <- safe_lookup(rb, ds, by=intersect(names(rb), names(ds)))
rb <- rb[!grepl("All Sites", rb$Site.ID),]
### keep only rows with crop and animal (livestoks)
#df <- rb[!grepl("Animal", rb$Product.Type),]
df <- rb[!grepl("^NA\\*\\*NA$", rb$Product.Type),]

#df$control <- ifelse(grepl("Yes", substr(df$T.Control, 1, 3)), TRUE, FALSE)
#df$treatment <- ifelse(is.na(df$T.Name) & !is.na(df$F.Level.Name), df$F.Level.Name, df$T.Name)

df$Out.Subind <- gsub(" ", "_", df$Out.Subind)
cols <- c("PD.Plant.Start", "PD.Plant.End", "PD.Harvest.Start", "PD.Harvest.End")
df[cols] <- lapply(df[cols], unclass)

d <- data.frame(
   yield_raw=ifelse(df$Out.Subind=="Crop_Yield", df$ED.Mean.T, NA),
   yield_unit_raw=ifelse(df$Out.Subind=="Crop_Yield", df$Out.Unit, NA),
   era_source_row=df$era_source_row,
   uri=df$B.DOI,
   reference= df$B.Author.Last,
   dataset_id= df$B.Code,
   location= df$Site.ID,
   on_farm= grepl("on-farm", tolower(df$Site.Type)),
   is_survey = grepl("survey", tolower(df$Site.Type)),
   country= df$Country,
   latitude= df$Site.LatD,
   longitude= df$Site.LonD,
   rain= df$Site.MAP,
   #temp= df$Site.MAT,
   elevation= df$Site.Elevation,
   soil_texture= df$Site.Soil.Texture,
   year= substr(df$Time, 1, 4),
   seasonal_prep= df$Time.Clim.SP,
   total_prec= df$Time.Clim.TAP,
   temp= as.numeric(df$Time.Clim.Temp.Mean),
   tmax= as.numeric(gsub("-9999", NA, df$Time.Clim.Temp.Max)),
   tmin= as.numeric(gsub("-9999", NA, df$Time.Clim.Temp.Min)),
   dsign= df$EX.Design,
   plot_area= df$EX.HPlot.Size,
   treatment= ifelse(is.na(df$T.Name) & !is.na(df$F.Level.Name), df$F.Level.Name, df$T.Name),
   control_T= ifelse(grepl("Yes", substr(df$T.Control, 1, 3)), TRUE, FALSE),
   crop= df$P.Product,
   harvest_start= df$PD.Harvest.Start,
   harvest_date= df$PD.Harvest.End,
   planting_date= ifelse(grepl("Planting",  df$PD.Plant.Variable), df$PD.Plant.Start, NA_character_) ,
   transplanting_date = ifelse(grepl("Transplanting",  df$PD.Plant.Variable), df$PD.Plant.Start, NA_character_) ,
   planting_end= df$PD.Plant.End,
   tillage= df$Till.Level.Name,
   land_prep_method= ifelse(is.na(df$T.Method)& !is.na(df$Till.Other), df$Till.Other, df$T.Method),
   land_prep_implement= df$T.Mechanization,
   variable= df$Out.Subind,
   yield_part= ifelse(is.na(df$ED.Product.Comp) & !is.na(df$ED.Product.Comp.L1), df$ED.Product.Comp.L1, df$ED.Product.Comp),
   value= df$ED.Mean.T,
   rep= ifelse(is.na(df$T.Reps) & !is.na(df$ED.Reps), df$ED.Reps, df$T.Reps),
   #df$T.Residue.Prev,
   variety= ifelse(is.na(df$V.Var) & !is.na(df$ED.Variety), df$ED.Variety, df$V.Var),
   variety_traits = ifelse(is.na(df$V.Trait1) & !is.na(df$V.Trait2), df$V.Trait2,
                    ifelse(is.na(df$V.Trait2) & !is.na(df$V.Trait3), df$V.Trait3, df$V.Trait1)), 
   variety_type = df$V.Type,
   maturity_days= df$V.Maturity,
   N_organic= df$F.NO,
   P_organic= df$F.PO,
   K_organic= df$F.KO,
   N_fertilizer= df$F.NI,
   P_fertilizer= ifelse(is.na(df$F.PI)& !is.na(df$F.P2O5), df$F.P2O5, df$F.PI),
   K_fertilizer= ifelse(is.na(df$F.KI)& !is.na(df$F.K2O),  df$F.K2O, df$F.KI),
   #fert_org_unit= df$F.O.Unit,
   #fert_Io_unit= df$F.I.Unit,
   irrigation_amount= df$I.Amount,
   irrigation_method= df$I.Method,
   irrigation_dates= ifelse(is.na(df$I.Date.Start) & !is.na(df$I.Date.Gen), df$I.Date.Gen, df$I.Date.Start),
   irrigation_dates_end= df$I.Date.End,
   irrigated= !is.na(df$I.Amount) & df$I.Amount != 0,
   planting_method= df$Plant.Method,
   planting_implement= df$Plant.Mechanization,
   plant_density= df$Plant.Density,
   units= df$Plant.Density.Unit,
   row_spacing= df$Plant.Row,
   intercrops=df$IN.Prod,
   crop_rotation= df$R.Prod.Seq,
   herbicide_used= ifelse(grepl("Herbicide", df$C.Type), TRUE, FALSE),
   herbicide_method= ifelse(grepl("Herbicide", df$C.Type), df$C.App.Method, "none"),
   herbicide_implement= ifelse(grepl("Herbicide", df$C.Type), df$C.Mechanization, "none"),
   herbicide_amount= ifelse(grepl("Herbicide", df$C.Type),df$C.Amount, 0),
   herbicide_product= ifelse(grepl("Herbicide", df$C.Type), df$C.Name, "none"),
   
   
   insecticide_used= ifelse(grepl("Insecticide|Bioinsecticide", df$C.Type), TRUE, FALSE),
   insecticide_method= ifelse(grepl("Insecticide|Bioinsecticide", df$C.Type), df$C.App.Method, "none"), 
   insecticide_implement= ifelse(grepl("Insecticide|Bioinsecticide", df$C.Type), df$C.Mechanization, "none"), 
   insecticide_amount= ifelse(grepl("Insecticide|Bioinsecticide", df$C.Type), df$C.Amount, 0), 
   insecticide_product= ifelse(grepl("Insecticide|Bioinsecticide", df$C.Type), df$C.Name, "none"),
   
   
   fungicide_used= ifelse(grepl("Fungicide|Biofungicide", df$C.Type), TRUE, FALSE),
   fungicide_method= ifelse(grepl("Fungicide|Biofungicide", df$C.Type), df$C.App.Method, "none"), 
   fungicide_implement= ifelse(grepl("Fungicide|Biofungicide", df$C.Type), df$C.Mechanization, "none"), 
   fungicide_amount= ifelse(grepl("Fungicide|Biofungicide", df$C.Type), df$C.Amount, 0), 
   fungicide_product= ifelse(grepl("Fungicide|Biofungicide", df$C.Type), df$C.Name, "none"),
   
   
   pesticide_used= ifelse(grepl("Biopesticide", df$C.Type), TRUE, FALSE),
   pesticide_method= ifelse(grepl("Biopesticide", df$C.Type), df$C.App.Method, "none"), 
   pesticide_implement= ifelse(grepl("Biopesticide", df$C.Type), df$C.Mechanization, "none"), 
   pesticide_amount= ifelse(grepl("Biopesticide", df$C.Type), df$C.Amount, 0), 
   pesticide_product= ifelse(grepl("Biopesticide", df$C.Type), df$C.Name, "none"),
   
   soil_clay= df$soil_clay,
   soil_depth= df$soil_depth,
   soil_sand= df$soil_sand,
   soil_silt= df$soil_silt,
   soil_pH= df$soil_pH,
   soil_EC= df$soil_EC,
   soil_bd= df$soil_BD,
   soil_P_total= df$soil_TP,
   product_type = df$Product.Type
)


### product type
prod <- strsplit(d$product_type, "\\*+")
max_len <- max(sapply(prod, length)) 
split_padded <- lapply(prod, function(x) {
   length(x) <- max_len
   return(x)
})

prod <- as.data.frame(do.call(rbind, split_padded), stringsAsFactors = FALSE)
d$product_type <- gsub("NA", NA, prod$V1)

##### livestock
lvsk <- d[which(d$product_type=="Animal"),]
d <- d[!grepl("Animal", d$product_type),]

### fixing rain value and type

rain <- strsplit(d$rain, "-|\\.+")
max_len <- max(sapply(rain, length)) 
split_padded <- lapply(rain, function(x) {
   length(x) <- max_len
   return(x)
})
rain <- as.data.frame(do.call(rbind, split_padded), stringsAsFactors = FALSE)
d$rain <- as.numeric(gsub("NA", NA, rain$V1))

### fixing elevation value and type

d$elevation <- suppressWarnings(as.numeric(d$elevation))


### Fixing soil texture
texture <- strsplit(d$soil_texture, "-|\\.\\.|/")
max_len <- max(sapply(texture, length)) 
split_padded <- lapply(texture, function(x) {
   length(x) <- max_len
   return(x)
})
text <- as.data.frame(do.call(rbind, split_padded), stringsAsFactors = FALSE)
d$soil_texture <- tolower(gsub("NA", NA, text$V1))
P <- fix_name(d$soil_texture)
P <- gsub("silt loam", "silty loam", P)
d$soil_texture <- P

### soil depth
depth <- as.data.frame(do.call(rbind, strsplit(d$soil_depth, "-")))
d$depth_bottom <- as.numeric(gsub("NA", NA, trimws(depth$V2)))
d$depth_top <- as.numeric(gsub("NA", NA, trimws(depth$V1)))
### fixing seed density unit 

d$seed_rate <- d$seed_density <- NA
d$seed_density <- ifelse(grepl("^kg seed/ha$|^seeds/ha$|seed clusters/ha", d$units), d$plant_density,
                         ifelse(grepl("seed/m2|kg seed/m2|grains/m2|seeds/m2|seeds/m",d$units), d$plant_density*10000, d$seed_density))  

d$seed_rate <- ifelse(grepl("kg/ha", d$units), d$plant_density, d$seed_rate)
d$plant_density <- ifelse(grepl("plants/m3|plants/m6|plants/m|plants/m4|plants/m2|plants/m5|plants/m7|hill/m2", d$units), d$plant_density*10000, d$plant_density) 

i <- !is.na(d$seed_density) | !is.na(d$seed_rate)  
d$plant_density[i] <- NA
d$units <- NULL


rotation <- strsplit(d$crop_rotation, "\\|+|\\.+")
max_len <- max(sapply(rotation, length)) 
split_padded <- lapply(rotation, function(x) {
   length(x) <- max_len
   return(x)
})
rota <- as.data.frame(do.call(rbind, split_padded), stringsAsFactors = FALSE)
d$crop_rotation <- tolower(gsub("NA", NA, rota$V1))
d$crop_rotation <- tolower(gsub("\\*+", ";", d$crop_rotation))

crop_rotation_map <- c(
  "acacia albida delile" = "acacia",
  "acacia angustissima" = "acacia",
  "acacia auriculiformis" = "acacia",
  "acacia crassicarpa" = "northern wattle",
  "acacia decurrens" = "green wattle",
  "acacia leptocarpa" = "north coast wattle",
  "albizia falcataria" = "falcataria",
  "albizia lebbeck" = "siris tree",
  "alchornea cordifolia" = "christmas bush",
  "alnus acuminata" = "andean alder",
  "bambara nut" = "bambara groundnut",
  "brachiaria brizantha" = "palisade grass",
  "brachiaria hybrid" = "brachiaria hybrid",
  "butter bean" = "lima bean",
  "calliandra calothyrsus" = "calliandra",
  "canola" = "Canola",
  "casuarina equisetifolia" = "australian pine",
  "chili" = "chili pepper",
  "clitoria ternatea" = "pea",
  "common vetch" = "vetch",
  "crotalaria grahamiana" = "rattlepod",
  "crotalaria juncea" = "sunn hemp",
  "crotalaria ochrolueca" = "rattlebox",
  "crotalaria paulina" = "crotalaria",
  "crotalaria sp" = "crotalaria",
  "crotalaria spectabilis" = "rattlebox",
  "cupressus lusitanica" = "mexican cypress",
  "dactyladenia barteri" = "dactyladenia",
  "egyptian clover" = "clover",
  "entada abyssinica" = "entada",
  "eucalyptus urograndis" = "eucalyptus hybrid",
  "fallow" = "none",
  "fava bean" = "faba bean",
  "flemingia sp" = "flemingia",
  "fodder radish" = "radish",
  "gliricidia sepium" = "gliricidia",
  "grazing vetch" = "vetch",
  "grevillea robusta" = "oak",
  "hyptis spicigera" = "sesame",
  "indian pea" = "grass pea",
  "jointvetche" = "vetch",
  "leucaena diversifolia" = "leucaena",
  "leucaena leucocephala" = "white leadtree",
  "leucaena pallida" = "leucaena",
  "maesopsis eminii" = "musizi",
  "markhamia lutea" = "nile tulip tree",
  "melia azedarach" = "chinaberry",
  "moringa oleifera" = "moringa",
  "natural fallow" = "none",
  "other fodder" = "none",
  "palisade grass" = "palisade grass",
  "patula pine" = "patula pine",
  "peas" = "pea",
  "peltophorum dubium" = "yellow poinciana",
  "pueraria phaseoloides" = "tropical kudzu",
  "ryegrass sp" = "ryegrass",
  "senna siamea" = "senna",
  "senna spectabilis" = "senna",
  "sesbania cannabina" = "sesbania",
  "sesbania sesban" = "egyptian riverhemp",
  "stylosanthes capitata" = "stylo",
  "stylosanthes guianensis" = "stylo",
  "stylosanthes hamata" = "stylo",
  "sweet potato" = "sweetpotato",
  "tephrosia candida" = "tephrosia",
  "tephrosia vogelii" = "fish-poison bean",
  "tithonia diversifolia" = "sunflower",
  "unspecified fodder grass" = "unknown",
  "unspecified legume" = "legume",
  "urochloa eminii" = "urochloa grass"
)

i <- d$crop_rotation %in% names(crop_rotation_map)
d$crop_rotation[i] <- crop_rotation_map[d$crop_rotation[i]]

d$treatment_type <- ifelse(grepl("TRUE", d$control_T), "control", "treatment")

### Fixing country
d$country <- ifelse(grepl("Uganda", d$country), "Uganda", 
             ifelse(grepl("Ethiopia", d$country), "Ethiopia", 
             ifelse(grepl("Malawi", d$country), "Malawi", 
             ifelse(grepl("Tanzania", d$country), "Tanzania", 
             ifelse(grepl("Benin..Togo", d$country), "Benin", 
             ifelse(grepl("Ghana..Benin", d$country), "Ghana", 
             ifelse(grepl("Kenya..Kenya", d$country), "Kenya", 
             ifelse(grepl("Drc|Congo", d$country), "Democratic Republic of the Congo", d$country))))))))

 d$country <- gsub("DRC|Democratic Republic of Congo", "Democratic Republic of the Congo", d$country)
 d$country <- gsub("Ivory Coast", "Côte d'Ivoire", d$country)
 d$country <- gsub("Swaziland", "Eswatini", d$country)
### Fixing intercrops

split <- strsplit(d$intercrops, "\\*+")
# Find the max number of parts in any row
max_len <- max(sapply(split, length))
# Pad each list element to the same length with NAs
split_padded <- lapply(split, function(x) {
   length(x) <- max_len
   return(x)
})

# bind the different rows
inter <- as.data.frame(do.call(rbind, split_padded), stringsAsFactors = FALSE)
inter$V3 <- ifelse(grepl("Mangifera indica", inter$V3), "Mangifera", 
                   ifelse(grepl("Leucaena leucocephala", inter$V3), "Leucaena", inter$V3))
inter$V2 <- ifelse(grepl("Poupartia silvatica", inter$V2), "Poupartia silvatica", 
            ifelse(grepl("Maize..Barley", inter$V2), "maize",
            ifelse(grepl("Terminalia ivoresensis", inter$V2), "Terminalia ivoresensis", 
            ifelse(grepl("Pearl Millet", inter$V2), "Pearl Millet", 
            ifelse(grepl("Mango..Papaya", inter$V2), "Mango", inter$V2)))))

d$intercrops <- tolower(
   apply(inter[, c("V2", "V3", "V4")], 1, function(x) {
      x <- x[!is.na(x) & trimws(x) != ""]
      paste(x, collapse = ";")
   })
)


inter_crop_map <- c(
   "banana sweet" = "banana",
   "common vetch" = "vetch",
   "cooking banana" = "banana",
   "cordia africana" = "african cordia",
   "cordia alliodora" = "laurel",
   "croton macrostachyus" = "croton",
   "cupressus lusitanica" = "mexican cypress",
   "dactyladenia barteri" = "dactyladenia",
   "desmodium intortum" = "greenleaf",
   "dracaena steudneri" = "dracaena",
   "ehretia cymosa" = "ehretia",
   "entada abyssinica" = "entada",
   "erythrina poeppigiana" = "immortelle tree",
   "eucalyptus alba" = "white gum",
   "eucalyptus deglupta" = "rainbow eucalyptus",
   "eucalyptus urograndis" = "eucalyptus hybrid",
   "faidherbia albida" = "apple",
   "fava bean" = "faba bean",
   "ficus vasta" = "fig",
   "flemingia macrophylla" = "flemingia",
   "gliricidia sepium" = "gliricidia",
   "gliricidia sp." = "gliricidia",
   "grevillea robusta" = "silky oak",
   "guiera senegalensis" = "guiera",
   "hibiscus" = "hibiscus",
   "inga densiflora" = "inga",
   "inga sp." = "inga",
   "leucaena diversifolia" = "leucaena",
   "leucaena leucocephala" = "white leadtree",
   "macadamia" = "macadamia",
   "maesopsis eminii" = "musizi",
   "maize..common bean" = "maize; common bean",
   "mangifera" = "mango",
   "markhamia lutea" = "nile tulip tree",
   "medicago scutellata" = "snail medic",
   "medicago truncatula" = "barrel medic",
   "melia azedarach" = "chinaberry",
   "milicia excelsa" = "iroko",
   "milletia ferruginea" = "millettia",
   "millettia ferruginea" = "millettia",
   "mimosa caesalpiniifolia" = "mimosa tree",
   "mucuna" = "velvet bean",
   "newbouldia laevis" = "boundary tree",
   "olea welwitshii" = "olive",
   "ornithopus sativus" = "pink serradella",
   "other fodder" = "unknown",
   "other millet" = "millet",
   "palisade grass" = "palisade grass",
   "palm oil" = "oil palm",
   "peltophorum dubium" = "yellow poinciana",
   "phoenix reclinata" = "palm",
   "poupartia silvatica" = "poupartia",
   "pouteria adolfi-friedericii" = "pouteria",
   "prunus africana" = "african cherry",
   "pueraria phaseoloides" = "tropical kudzu",
   "purple vetch" = "purple vetch",
   "rice bean" = "rice",
   "ruzigrass" = "ruzi grass",
   "schefflera abyssinica" = "schefflera",
   "senna siamea" = "senna",
   "senna spectabilis" = "senna",
   "sesbania rostrata" = "sesbania",
   "sesbania sesban" = "egyptian riverhemp",
   "silverleaf" = "Silver leaf",
   "solanum sp." = "solanum",
   "squash (c.moschata)" = "butternut squash",
   "stylosanthes capitata" = "stylo",
   "stylosanthes guianensis" = "stylo",
   "stylosanthes hamata" = "stylo",
   "sugar cane" = "sugarcane",
   "sweet potato" = "sweetpotato",
   "tephrosia candida" = "tephrosia",
   "tephrosia vogelii" = "fish-poison bean",
   "terminalia amazonia" = "yellow terminalia",
   "terminalia ivorensis" = "idigbo",
   "terminalia ivoresensis" = "idigbo",
   "tick clover sp" = "clover",
   "trifolium subterraneum" = "clover",
   "unspecified" = "Unknown",
   "unspecified fodder grass" = "legume",
   "unspecified legume" = "legume",
   "unspecified tree" = "unknown",
   "urochloa decumbens" = "signal grass",
   "urochloa eminii" = "urochloa",
   "vepris dainellii" = "epris",
   "vetiver grass" = "Vetiver",
   "vicia villosa" = "hairy vetch",
   "winter vetch" = "winter vetch",
   "ziziphus mauritiana" = "indian jujube"
)

i <- d$intercrops %in% names(inter_crop_map)
d$intercrops[i] <- inter_crop_map[d$intercrops[i]]


i <- which(d$K_organic!=0 | d$N_organic!=0 |d$P_organic!=0)
d$OM_used <- FALSE
d$OM_used[i] <- TRUE

# Map whole labels only. Leave mixtures and unresolved labels in crop_raw.
d$crop_raw <- d$crop
key <- function(x) tolower(trimws(x))
crosswalk <- read.csv("report/audit/crop_labels.csv",check.names=FALSE,na.strings="")
stopifnot(!anyDuplicated(crosswalk[["raw label"]]))
d$crop <- crosswalk[["resolved product"]][match(key(d$crop_raw),crosswalk[["raw label"]])]
## Fixing planting method and implement

P <- fix_name(tolower(d$planting_method))
P <- gsub("unspecified", "unknown", P)
P <- gsub("direct drilling/sowing", "direct seeding", P)
P <- gsub("dibble stick", "dibbling", P)
P <- gsub("direct-seeding plante", "direct seeding", P)
P <- gsub("zero-tillage planter", "none", P)
P <- gsub("drill planter", "mechanized", P)
P <- gsub("cuttings", "unknown", P)
P <- gsub("drilling", "mechanized", P)
P <- gsub("cutlasses", "unknown", P)
P <- gsub("manual hoe seeding", "manual", P)
P <- gsub("hand seeding", "manual", P)
P <- gsub("manual S=seeding", "manual", P)
P <- gsub("drilled into furrows", "mechanized", P)
P <- gsub("ratoon", "unknown", P)
P <- gsub("ripline", "unknown", P)
P <- gsub("dribble", "mechanized", P)
P <- gsub("furrows", "unknown", P)
P <- gsub("jab matraca planter", "unknown", P)
P <- gsub("no-till planter", "none", P)
P <- gsub("agoye ripper rip-line", "unknown", P)
P <- gsub("hand-hoe planting holes", "manual", P)
P <- gsub("jab planter|ridges", "unknown", P)
P <- gsub("manual seeding|hand plante", "manual", P)
P <- gsub("tine planter", "unknown", P)
P <- gsub("mline sowing", "line sowing", P)
P <- gsub("direct seedingr", "direct seeding", P)
d$planting_method <- P

P <- fix_name(d$planting_implement)
P <- gsub("Unspecified", "unknown", P)
P <- gsub("Tractor", "4 wheel tractor", P)
P <- gsub("Animal labour", "animal", P)
P <- gsub("Manual labour", "manual", P)
P <- gsub("Not in template", "none", P)
P <- gsub("uu", "unknown", P)
P <- gsub("planter|Planter", "jab planter", P)
d$planting_implement <- P

# Do not repair ambiguous coordinate strings or discard valid precision.
coord <- function(x,limit) {
  z <- suppressWarnings(as.numeric(trimws(x)))
  z[!is.finite(z) | abs(z)>limit] <- NA_real_
  z
}
d$latitude <- coord(d$latitude,90)
d$longitude <- coord(d$longitude,180)
### fixing location 
loc <- strsplit(d$location, "\\.\\.")
max_len <- max(sapply(loc, length)) 
split_padded <- lapply(loc, function(x) {
   length(x) <- max_len
   return(x)
})

loc <- as.data.frame(do.call(rbind, split_padded), stringsAsFactors = FALSE)
d$location <- fix_name(loc$V1, "title")

#### Fixing maturity days
md <- strsplit(d$maturity_days, "\\.+")
max_len <- max(sapply(md, length)) 
split_padded <- lapply(md, function(x) {
   length(x) <- max_len
   return(x)
})

mt <- as.data.frame(do.call(rbind, split_padded), stringsAsFactors = FALSE)
d$maturity_days <- mt$V1
d$maturity_days <- as.numeric(gsub("Na", NA, ifelse(grepl("\\$", d$maturity_days), NA, d$maturity_days)))

### Fixing variety type 

V <- strsplit(d$variety_type, "\\.+")
max_len <- max(sapply(V, length)) 
split_padded <- lapply(V, function(x) {
   length(x) <- max_len
   return(x)
})

Vt <- as.data.frame(do.call(rbind, split_padded), stringsAsFactors = FALSE)
d$variety_type <- Vt$V1

### Fixing variety 

V <- strsplit(d$variety, "\\.+")
max_len <- max(sapply(V, length)) 
split_padded <- lapply(V, function(x) {
   length(x) <- max_len
   return(x)
})

Vty <- as.data.frame(do.call(rbind, split_padded), stringsAsFactors = FALSE)
d$variety <- gsub("\\*+", ";", Vty$V1)

### Fixing variety traits

V <- strsplit(d$variety_traits, "\\.+")
max_len <- max(sapply(V, length)) 
split_padded <- lapply(V, function(x) {
   length(x) <- max_len
   return(x)
})

Vtr <- as.data.frame(do.call(rbind, split_padded), stringsAsFactors = FALSE)
d$variety_traits <- gsub("NA", NA, Vtr$V1)


### Fixing irrigation method
d$irrigation_method <- ifelse(grepl("Irrigation \\(Other\\)", d$irrigation_method), "Irrigation (Other)", d$irrigation_method)
P <- fix_name(d$irrigation_method)
P <- gsub("Drip Irrigation", "drip", P)
P <- gsub("Irrigation \\(Other\\)", "unknown", P)
P <- gsub("Flood \\(Complete\\)", "flood", P)
P <- gsub("Flood \\(Furrow\\)", "flood", P)
P <- gsub("Unspecified", "unknown", P)
P <- gsub("Drip \\(b34\\)", "drip", P)
P <- gsub("Sprinkler \\(b72\\)", "sprinkler", P)
P <- gsub("Other \\(b53\\)", "unknown", P)
P <- gsub("Sprinkler Irrigation", "sprinkler", P)
P <- gsub("NA", NA, P)
d$irrigation_method <- P

# Parse single values; do not truncate decimals or guess concatenated rates.
for (k in c("N_fertilizer","P_fertilizer","K_fertilizer")) {
  z <- suppressWarnings(as.numeric(trimws(d[[k]])))
  z[!is.finite(z) | z<0 | z %in% c(999,999999)] <- NA_real_
  d[[k]] <- z
}
## Fixing herbicide product

d$herbicide_product <- tolower(trimws(d$herbicide_product))
herbicide_map <- c(
   "acetanilide" = "butachlor",  
   "altrazine" = "atrazine",
   "bispyribac sodium" = "bispyribac-sodium",
   "bullet" = "atrazine",      
   "butachlor" = "butachlor",
   "buty ester" = "2,4-d",
   "chlorimuron" = "chlorimuron-ethyl", # not in carob
   "diclofop-methyl" = "diclofop-methyl", # not in carob
   "dual" = "metolachlor",
   "dual gold" = "s-metolachlor",
   "ethoxisulfuron" = "ethoxysulfuron", # not in carob
   "fenoxaprop" = "fenoxaprop-p-ethyl",
   "florasulam" = "florasulam",
   "fluaifop-butyl" = "fluazifop-butyl",
   "fluazifop-p-butyl" = "fluazifop-p-butyl",
   "flumetsulam" = "flumetsulam", # not in carob
   "fomesafen" = "fomesafen", # not in carob
   "furadan 5g" = "carbofuran",  # not in carob
   "gramoxone" = "paraquat dichloride",
   "imazaquin" = "imazaquin", # not in carob
   "imazethapyr" = "imazethapyr, ammonium salt",
   "l-l'-dimethyl-4,4'-bipyridinium" = "paraquat dichloride",
   "lasso" = "alachlor",
   "metsulfuron-methyl" = "metsulfuron",
   "mustang 306 se" = "florasulam", 
   "n-(phosphono-methyl) glycine" = "glyphosate",
   "paraquat" = "paraquat dichloride",
   "primagram" = "unknown",   # 
   "prosulfuron" = "prosulfuron", # Not in carob
   "quizalofop-p-ethyl" = "quizalofop-p-ethyl", # not in carob
   "stomp" = "pendimethalin",
   "sulfentrazone" = "sulfentrazone",
   "thifensulfuron-methyl" = "thifensulfuron-methyl",# not in carob
   "topic (15wp)" = "clodinafop",
   "unspecified" = "unknown",
   "weedall" = "glyphosate"
)

i <- d$herbicide_product %in% names(herbicide_map)
d$herbicide_product[i] <- herbicide_map[d$herbicide_product[i]]

### Fixing fungicide
d$fungicide_product <- tolower(trimws(d$fungicide_product))

fungicide_map <- c(
   "apron plus" = "mefenoxam; fludioxonil",
   "bayleton 25 wp" = "triadimefon",
   "bonsoin" = "chlorothalonil;cymoxanil",
   "carbendazim + thiram" = "carbendazim; thiram", # carbendazim: Not in carob
   "fox" = "prothioconazole;trifloxystrobin",
   "malathion" = NA,# insecticide
   "manzate d" = "mancozeb",
   "maxim" = "fludioxonil",
   "maxim xl" = "mefenoxam; fludioxonil",
   "nativo" = "tebuconazole; trifloxystrobin",
   "nobel 25 wp" = "triadimefon",
   "opera" = "pyraclostrobin; epoxiconazole",
   "pencycuron" = "pencycuron",
   "potassium silicate" = "potassium silicate",
   "propiconazole" = "propiconazole",
   "pyraclostrobin" = "pyraclostrobin",
   "ridomilgold mz 68 wg" = "metalaxyl-m; mancozeb",
   "rizolex-t50" = "tolclofos-methyl; thiram",
   "sphere max" = "trifloxystrobin;cyproconazole",
   "unspecified" = "unknown",
   "vitavax" = "carboxin"
)

i <- d$fungicide_product %in% names(fungicide_map)
d$fungicide_product[i] <- fungicide_map[d$fungicide_product[i]]


## Fixing insecticide

d$insecticide_product <- tolower(trimws(d$insecticide_product))

insecticide_map <- c(
   "abamectin" = "abamectin",
   "ampligo" = "chlorantraniliprole; lambda-cyhalothrin",
   "belt" = "flubendiamide",
   "bestox" = "alpha-cypermethrin",
   "bulldock" = "beta-cyfluthrin",
   "cyhalothrin" = "lambda-cyhalothrin",
   "cypadem" = "cypermethrin",
   "cyproconazole" = NA, # fungicide, not insecticide
   "dipterex" = "trichlorfon",
   "fenvalerate" = "fenvalerate",
   "imidacloprid" = "imidacloprid",
   "karate" = "lambda-cyhalothrin",
   "nuvacron" = "monocrotophos",
   "pirimicarb" = "pirimicarb",
   "sulfuramid" = "sulfuramid", # not in carob
   "termex" = "imidacloprid;bifenthrin",
   "thiodan" = "endosulfan",
   "thunder" = "thiamethoxam;tolfenpyrad",
   "trichlorophon" = "trichlorfon",
   "unspecified" = "unknown",
   "vetox 85" = "carbaryl",
   "warrant power" = "gamma-cyhalothrin"
)

i <- d$insecticide_product %in% names(insecticide_map)
d$insecticide_product[i] <- insecticide_map[d$insecticide_product[i]]


##############################################################
#### Transforming response variable from long into wide format ##########

# Preserve one row per source outcome; row order across variables is not a plot ID.
d <- d[!is.na(d$variable) & nzchar(d$variable),]
dwf <- tidyr::pivot_wider(d,names_from=variable,values_from=value)
stopifnot(!anyDuplicated(dwf$era_source_row))
outcomes <- c(
  "Crop_Yield" = "yield",
  "Soil_Organic_Carbon" = "soil_SOC",
  "Soil_Total_Nitrogen" = "soil_N_total",
  "Soil_Nitrogen" = "soil_N",
  "Soil_Organic_Matter" = "soil_SOM",
  "Carbon_Dioxide_Emissions" = "emission_CO2",
  "Soil_Organic_Carbon_(Change)" = "soil_SOC_exch",
  "CO2_Equivalent_Emissions" = "CO2_eq_emission",
  "Variable_Cost_per_Unit_Product" = "variable_cost",
  "Aboveground_Biomass" = "fwy_total",
  "Pest_&_Pathogen_(Losses)" = "pest_severity",
  "Effective_Cation_Exchange_Capacity" = "soil_CEC_eff",
  "Methane_Emissions" = "emission_CH4",
  "Nitrous_Oxide_Emissions" = "emission_N2O",
  "Cation_Exchange_Capacity" = "soil_CEC",
  "Erosion" = "soil_erosion",
  "Labour_Cost" = "labour_Cost",
  "Labour_Person_Hours" = "labour",
  "Net_Return" = "net_benefit",
  "Soil_Carbon_Stocks" = "soil_C_stock"
)
mapped <- match(names(dwf),names(outcomes))
names(dwf)[!is.na(mapped)] <- unname(outcomes[mapped[!is.na(mapped)]])
# Exact units only: case matters (Mg is not mg). Preserve unconverted source values.
y <- suppressWarnings(as.numeric(dwf$yield_raw))
scale <- c("kg/ha"=1,"Mg/ha"=1000,"t/ha"=1000,"g/m2"=10)
dwf$yield <- ifelse(is.finite(y) & y>=0,y*unname(scale[trimws(dwf$yield_unit_raw)]),NA_real_)


### fixing tillage
dwf$land_prep_method <- ifelse(is.na(dwf$land_prep_method) & !is.na(dwf$tillage), "tillage", dwf$land_prep_method)
dwf$id <- dwf$tillage <- NULL
 ### Fixing land prep 

dwf$land_prep_method <- tolower(ifelse(grepl("CT|CONV|ConvTill|conv|CON|Conservation|Direct|Conv|CA|Conventional", dwf$land_prep_method), "conventional", 
                               ifelse(grepl("MT|Min Till", dwf$land_prep_method), "minimum tillage",
                               ifelse(grepl("Disc", dwf$land_prep_method), "disk tillage", 
                               ifelse(grepl("NT|ZT|no-till|NoTill|Control|No till|No Till|No-till|T0|FlatUntill|zero", dwf$land_prep_method), "zero tillage", 
                               ifelse(grepl("Ridge|Ridging|ridge|ridging", dwf$land_prep_method), "ridge tillage", 
                               ifelse(grepl("RT|reduced|Reduced", dwf$land_prep_method), "reduced tillage",
                               ifelse(grepl("Chiseling", dwf$land_prep_method), "deep ploughing",
                               ifelse(grepl("Hand Hoe|Hand hoe|hoe|hue", dwf$land_prep_method), "hoeing", 
                               ifelse(grepl("Ploughed|Plough|plough", dwf$land_prep_method), "ploughing", 
                               ifelse(grepl("Rotary Plough|ratovator|rotovator|rotovating|rotavator", dwf$land_prep_method), "rotovating",
                               ifelse(grepl("Mali Tillage|BF Tillage|Niger Tillage|Tillage|Till|Maize till|RedTill|FlatTill|Plow-till|till|shallow tillag|manual tilling|no furrow", dwf$land_prep_method), "tillage", 
                               ifelse(grepl("Planting Basins|Basins|BASINS|basin", dwf$land_prep_method), "basins", 
                               ifelse(grepl("Non-puddling NP", dwf$land_prep_method), "not puddled", 
                               ifelse(grepl("permbeds|broadpermbeds", dwf$land_prep_method), "permanent beds", 
                               ifelse(grepl("puddled plots", dwf$land_prep_method), "puddled",
                               ifelse(grepl("furrow dikes|furrows", dwf$land_prep_method), "open furrows",
                               ifelse(grepl("Puddling P", dwf$land_prep_method), "puddled", dwf$land_prep_method))))))))))))))))))


dwf$tillage <- NULL



### Yield part 

dwf$yield_part <- tolower(ifelse(grepl("Grain/Seed", dwf$yield_part), "grain", 
                  ifelse(grepl("Pods", dwf$yield_part), "pod",
                  ifelse(grepl("Fruit", dwf$yield_part), "fruit", 
                  ifelse(grepl("Tuber/Root|Bulb", dwf$yield_part), "roots",
                  ifelse(grepl("Corm|Cormel|corn", dwf$yield_part), "grain",
                  ifelse(grepl("Wood", dwf$yield_part), "wood",
                  ifelse(grepl("Stem/Stalks|^Stalks$", dwf$yield_part), "stems",
                  ifelse(grepl("Whole Plant|Stalks\\+Leaves", dwf$yield_part), "aboveground biomass",
                  ifelse(grepl("Biomass|Haulm", dwf$yield_part), "biomass",
                  ifelse(grepl("Unspecified|Gum/Sap|Cane|gh", dwf$yield_part), "none",
                  ifelse(grepl("Fibre|Suga", dwf$yield_part), "fibres",
                  ifelse(grepl("Nuts", dwf$yield_part), "pod", dwf$yield_part)))))))))))))


### drop rows with missing crop 
# Keep unresolved crop rows traceable in the exploratory output.
 

#carobiner::write_files(path, meta, dwf)





