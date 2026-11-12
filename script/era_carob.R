# Exploratory broad-schema conversion. Run audit/prepare.py first.
library(dplyr)
library(tidyr)
source("script/pinned.R")
source("script/agronomy.R")
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
   value= map_site_measure(r2$variable,r2$value,r2$Unit)
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

df$era_outcome_raw <- df$Out.Subind
df$Out.Subind <- gsub(" ", "_", df$Out.Subind)
cols <- c("PD.Plant.Start", "PD.Plant.End", "PD.Harvest.Start", "PD.Harvest.End")
df[cols] <- lapply(df[cols], unclass)

d <- data.frame(
   yield_raw=ifelse(df$Out.Subind=="Crop_Yield", df$ED.Mean.T, NA),
   yield_unit_raw=ifelse(df$Out.Subind=="Crop_Yield", df$Out.Unit, NA),
   era_source_row=df$era_source_row,
   era_outcome_raw=df$era_outcome_raw,
   era_value_raw=df$ED.Mean.T,
   era_unit_raw=df$Out.Unit,
   era_data_location=df$ED.Data.Loc,
   era_season_raw=df$Time,
   era_outcome_error_raw=df$ED.Error,
   era_error_type_raw=df$ED.Error.Type,
   era_control_raw=df$T.Control,
   era_treatment_reps_raw=df$T.Reps,
   era_outcome_reps_raw=df$ED.Reps,
   era_n_replicates=ifelse(is.na(df$ED.Reps),whole_reps(df$T.Reps),whole_reps(df$ED.Reps)),
   era_site_map_raw=df$Site.MAP,
   era_irrigation_amount_raw=df$I.Amount,
   era_irrigation_unit_raw=df$I.Unit,
   era_irrigation_method_raw=df$I.Method,
   era_irrigation_level_raw=df$I.Level.Name,
   uri=df$B.DOI,
   reference= df$B.Author.Last,
   dataset_id= df$B.Code,
   location= df$Site.ID,
   on_farm= ifelse(df$Site.Type %in% c("Farm","Researcher Managed & On-farm"),TRUE,
               ifelse(df$Site.Type %in% c("Station","Researcher Managed & Research Facility"),FALSE,NA)),
   is_survey = grepl("survey", tolower(df$Site.Type)),
   country= df$Country,
   latitude= df$Site.LatD,
   longitude= df$Site.LonD,
   rain= NA_real_, # Site.MAP is a long-term annual mean.
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
   control_T= unname(c("Yes"=TRUE,"No"=FALSE)[df$T.Control]),
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
   rep= NA_integer_, # ERA counts replicates; Carob rep identifies an individual replicate.
   #df$T.Residue.Prev,
   variety= ifelse(is.na(df$V.Var) & !is.na(df$ED.Variety), df$ED.Variety, df$V.Var),
   variety_traits = ifelse(is.na(df$V.Trait1) & !is.na(df$V.Trait2), df$V.Trait2,
                    ifelse(is.na(df$V.Trait2) & !is.na(df$V.Trait3), df$V.Trait3, df$V.Trait1)), 
   variety_type = df$V.Type,
   maturity_days= df$V.Maturity,
   N_organic= fertilizer_rate(df$F.NO,df$F.O.Unit),
   P_organic= fertilizer_rate(df$F.PO,df$F.O.Unit),
   K_organic= fertilizer_rate(df$F.KO,df$F.O.Unit),
   N_fertilizer= fertilizer_rate(df$F.NI,df$F.I.Unit),
   P_fertilizer= fertilizer_rate(df$F.PI,df$F.I.Unit,df$F.P2O5,element_fraction=0.4364),
   K_fertilizer= fertilizer_rate(df$F.KI,df$F.I.Unit,df$F.K2O,element_fraction=0.8301),
   irrigation_amount= convert_measure(df$I.Amount,df$I.Unit,c("mm/season"=1)),
   irrigation_method= df$I.Method,
   irrigation_dates= ifelse(is.na(df$I.Date.Start) & !is.na(df$I.Date.Gen), df$I.Date.Gen, df$I.Date.Start),
   irrigation_dates_end= df$I.Date.End,
   irrigated= irrigation_flag(df$I.Amount,df$I.Method,df$I.Level.Name),
   planting_method= df$Plant.Method,
   planting_implement= df$Plant.Mechanization,
   plant_density= df$Plant.Density,
   units= df$Plant.Density.Unit,
   row_spacing= df$Plant.Row,
   intercrops=df$IN.Prod,
   crop_rotation= df$R.Prod.Seq,
   era_chemical_type_raw=df$C.Type,
   era_chemical_name_raw=df$C.Name,
   era_chemical_amount_raw=df$C.Amount,
   era_chemical_unit_raw=df$C.Unit,
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


# A positive chemical record supports use of its class only. An omitted
# chemical, an unclassified treatment or a record for another class is unknown.
classes <- list(herbicide="Herbicide", insecticide=c("Insecticide","Bioinsecticide"),
                fungicide=c("Fungicide","Biofungicide"),pesticide="Biopesticide")
for (kind in names(classes)) {
  documented <- df$C.Type %in% classes[[kind]]
  quantity <- suppressWarnings(as.numeric(df$C.Amount))
  d[[paste0(kind,"_used")]] <- ifelse(documented & (is.na(quantity) | quantity>0),TRUE,NA)
  d[[paste0(kind,"_method")]] <- ifelse(documented,df$C.App.Method,NA_character_)
  d[[paste0(kind,"_implement")]] <- ifelse(documented,df$C.Mechanization,NA_character_)
  # The Carob amount is kg active ingredient/ha. Product mass or volume alone
  # does not establish the amount of active ingredient.
  d[[paste0(kind,"_amount")]] <- ifelse(documented,
      convert_measure(df$C.Amount,df$C.Unit,c("g a.i./ha"=.001,"kg a.i./ha"=1)),NA_real_)
  d[[paste0(kind,"_product")]] <- ifelse(documented & df$C.Name.Type %in% "Chemical",
                                         tolower(trimws(df$C.Name)),NA_character_)
}

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
# Count per area, seed mass per area and emerged plant density are separate.
d$seed_rate <- convert_measure(d$plant_density,d$units,c("kg seed/ha"=1,"kg/ha"=1,"kg seed/m2"=10000))
d$seed_density <- convert_measure(d$plant_density,d$units,c("seeds/ha"=1,"seeds/m2"=10000,"seed/m2"=10000,"grains/m2"=10000))
d$plant_density <- convert_measure(d$plant_density,d$units,c("plants/ha"=1,"plants/m2"=10000))
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

d$treatment_type <- ifelse(d$control_T, "control", "treatment")

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
d$OM_used <- NA
d$OM_used[i] <- TRUE

# Map whole labels only. Leave mixtures and unresolved labels in crop_raw.
d$crop_raw <- d$crop
crosswalk <- current_crop_crosswalk(era_master,d$crop)
stopifnot(!anyDuplicated(crosswalk[["raw label"]]))
d$crop <- crosswalk[["resolved product"]][match(crop_key(d$crop_raw),crosswalk[["raw label"]])]
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

##############################################################
#### Transforming response variable from long into wide format ##########

# Preserve one row per source outcome; row order across variables is not a plot ID.
d <- d[!is.na(d$variable) & nzchar(d$variable),]
dwf <- d
stopifnot(!anyDuplicated(dwf$era_source_row))
dwf$yield <- convert_measure(dwf$yield_raw,dwf$yield_unit_raw,mass_area)
for (rule in list(
    list("Soil_Organic_Carbon","soil_SOC",percent_mass),
    list("Soil_Organic_Matter","soil_SOM",percent_mass),
    list("Soil_Total_Nitrogen","soil_N_total",nitrogen_mgkg),
    # ERA Soil Nitrogen leaves the N fraction unspecified. Carob soil_N requires extractable N.
    list("Cation_Exchange_Capacity","soil_CEC",c("cmol/kg"=1,"cmolc/kg"=1,"meq/100g"=1)),
    list("Soil_Organic_Carbon","era_soc_stock_mg_ha",carbon_stock),
    list("Soil_Carbon_Stocks","era_carbon_stock_mg_ha",carbon_stock))) {
  selected <- which(dwf$variable==rule[[1]])
  dwf[[rule[[2]]]] <- NA_real_
  dwf[[rule[[2]]]][selected] <- convert_measure(dwf$value[selected],dwf$era_unit_raw[selected],rule[[3]])
}

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



# Preserve the detailed component even when no Carob category is justified.
dwf$yield_part_raw <- dwf$yield_part
dwf$yield_part <- ifelse(dwf$variable=="Crop_Yield",map_harvest_part(dwf$yield_part_raw),NA_character_)
era_provenance_cols <- c(setdiff(grep("^era_",names(dwf),value=TRUE),"era_source_row"),"yield_part_raw","control_T")
dwf$variable <- NULL
dwf$value <- NULL
