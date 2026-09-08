## ERA TO CAROB FORMAT

# Run once to install dependencies:
#install.packages(c("s3fs", "arrow", "terra", "remotes"), type = "binary")
# remotes::install_github("carob-data/caramba")

library(tidyr)
library(dplyr)
library(s3fs)
library(arrow)
library(jsonlite)
library(caramba)

# Load ERA data from S3
s3 <- s3fs::S3FileSystem$new(anonymous = TRUE)
era_s3 <- "s3://digital-atlas/era"
bundle_dir <- file.path(era_s3, "data", "packaged")

all_files <- s3$dir_ls(bundle_dir)
latest_bundle <- tail(sort(grep("era_agronomy_bundle.*\\.tar\\.gz$", all_files, value = TRUE)), 1)

dl_dir <- "downloaded_data"
dir.create(dl_dir, showWarnings = FALSE)
bundle_local <- file.path(dl_dir, basename(latest_bundle))
extract_dir <- file.path(dl_dir, tools::file_path_sans_ext(tools::file_path_sans_ext(basename(latest_bundle))))

if (!file.exists(bundle_local)) {
  s3$file_download(latest_bundle, bundle_local, overwrite = TRUE)
}
if (!dir.exists(extract_dir)) {
  dir.create(extract_dir)
  utils::untar(bundle_local, exdir = extract_dir)
}

json_agronomic <- list.files(extract_dir, pattern = "^agronomic_.*\\.json$", full.names = TRUE)
json_master    <- list.files(extract_dir, pattern = "^era_master_codes.*\\.json$", full.names = TRUE)
parquet_file   <- list.files(extract_dir, pattern = "^era_compiled.*\\.parquet$", full.names = TRUE)

ERA_Compiled <- arrow::read_parquet(parquet_file)
era_merge    <- jsonlite::fromJSON(json_agronomic[1], simplifyDataFrame = TRUE)
era_master   <- jsonlite::fromJSON(json_master[1],    simplifyDataFrame = TRUE)

### Baseline data 
rb <-  do.call(carobiner::bindr, era_merge["Data.Out"])

#### adding missing variables from prod.out to Data.out
r5 <- do.call(carobiner::bindr, era_merge["Prod.Out"])
rb <- merge(rb, r5,  by= intersect(names(rb), names(r5)), all = TRUE)

### Adding Tillage variables from Till.out to Data.out
r7 <- do.call(carobiner::bindr, era_merge["Till.Out"])
rb <- merge(rb, r7,  by= intersect(names(rb), names(r7)), all = TRUE)

### Adding planting management information 
r9 <- do.call(carobiner::bindr, era_merge["Plant.Method"])
rb <- merge(rb, r9,  by= intersect(names(rb), names(r9)), all = TRUE)

### Adding fertilizer method
r12 <- do.call(carobiner::bindr, era_merge["Fert.Method"])
rb <- merge(rb, r12,  by= intersect(names(rb), names(r12)), all = TRUE)

### Adding chemical elements 
r15 <- do.call(carobiner::bindr, era_merge["Chems.Out"])
rb <- merge(rb, r15,  by= intersect(names(rb), names(r15)), all = TRUE)

#### residue 
r18 <-  unclass(do.call(carobiner::bindr, era_merge["Res.Method"]) )
rb <- merge(rb, r18,  by= intersect(names(rb), names(r18)), all = TRUE)

## residue composition 
r19 <-  do.call(carobiner::bindr, era_merge["Res.Comp"]) 
rb <- merge(rb, r19,  by= intersect(names(rb), names(r19)), all = TRUE)

#### 
r21 <-  do.call(carobiner::bindr, era_merge["pH.Out"]) 
rb <- merge(rb, r21,  by= intersect(names(rb), names(r21)), all = TRUE)

####
r22 <-  do.call(carobiner::bindr, era_merge["pH.Method"]) 
rb <- merge(rb, r22,  by= intersect(names(rb), names(r22)), all = TRUE)

##### irrigation
r23 <-  do.call(carobiner::bindr, era_merge["Irrig.Method"])
rb <- merge(rb, r23,  by= intersect(names(rb), names(r23)), all = TRUE)

###
r25 <-  do.call(carobiner::bindr, era_merge["WH.Out"])
rb <- merge(rb, r25,  by= intersect(names(rb), names(r25)), all = TRUE)

### Add soil data 
r2 <- do.call(carobiner::bindr, era_merge["Soil.Out"])
d1 <- data.frame(
   Site.ID= r2$Site.ID,
   soil_depth= paste0(r2$Soil.Upper, "-", r2$Soil.Lower),
   B.Code= r2$B.Code,
   variable= r2$variable,
   value= r2$value
)

proc_soil <- function(f){
   
   d2 <- d1[d1$B.Code==f,]
   
   ### Adding  step in the data to facilitate the transformation from long to wide 
   ds <- d2 %>%
      group_by(variable) %>%
      mutate(id = row_number()) %>%
      ungroup()
   df <- ds %>%
      pivot_wider(
         id_cols = names(ds)[!grepl("variable|value", names(ds))],
         names_from = variable ,        
         values_from = value      
      )
   
   return(df)
   
}

#### Append the data base on the study (B_code)
ff <- unique(r2$B.Code)
ds <- lapply(ff, proc_soil)
ds <- do.call(carobiner::bindr, ds)
ds$id <- NULL
names(ds) <- gsub("Soil.", "soil_", names(ds))
i <- grep("CLY|SLT|SND|soil_AP", names(ds))
names(ds)[i] <-  c("soil_clay","soil_silt","soil_sand", "soil_P_available")

rb <- merge(rb, ds, by= intersect(names(rb), names(ds)), all= TRUE)
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
   uri=df$B.DOI,
   reference= df$B.Author.Last,
   dataset_id= df$B.Code,
   location= df$Site.ID,
   on_farm= grepl("On-farm", tolower(df$Site.Type)),
   is_survey = grepl("survey", tolower(df$Site.Type)),
   country= df$Country,
   latitude= substr(df$Site.LatD, 1, 6),
   longitude= substr(df$Site.LonD,1, 6),
   rain= df$Site.MAP,
   temp= df$Site.MAT,
   elevation= df$Site.Elevation,
   soil_type= df$Site.Soil.Texture,
   year= substr(df$Time, 1, 4),
   seasonal_prep= df$Time.Clim.SP,
   total_prec= df$Time.Clim.TAP,
   temp= df$Time.Clim.Temp.Mean,
   tmax= as.numeric(gsub("-9999", NA, df$Time.Clim.Temp.Max)),
   tmin= as.numeric(gsub("-9999", NA, df$Time.Clim.Temp.Min)),
   dsign= df$EX.Design,
   plot_area= df$EX.HPlot.Size,
   treatment= ifelse(is.na(df$T.Name) & !is.na(df$F.Level.Name), df$F.Level.Name, df$T.Name),
   control_T= ifelse(grepl("Yes", substr(df$T.Control, 1, 3)), TRUE, FALSE),
   crop= df$P.Product,
   harvest_date= df$PD.Harvest.Start,
   harvest_end= df$PD.Harvest.End,
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
   irrigation_date= ifelse(is.na(df$I.Date.Start) & !is.na(df$I.Date.Gen), df$I.Date.Gen, df$I.Date.Start),
   irrigation_date_end= df$I.Date.End,
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
   pesticide_used_method= ifelse(grepl("Biopesticide", df$C.Type), df$C.App.Method, "none"), 
   pesticide_used_implement= ifelse(grepl("Biopesticide", df$C.Type), df$C.Mechanization, "none"), 
   pesticide_used_amount= ifelse(grepl("Biopesticide", df$C.Type), df$C.Amount, 0), 
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

### fixing rain value and type

rain <- strsplit(d$rain, "-|\\.\\.")
max_len <- max(sapply(rain, length)) 
split_padded <- lapply(rain, function(x) {
   length(x) <- max_len
   return(x)
})
rain <- as.data.frame(do.call(rbind, split_padded), stringsAsFactors = FALSE)
d$rain <- as.numeric(gsub("NA", NA, rain$V1))

## Fixing temp

temp <- strsplit(d$temp, "-|\\.\\.")
max_len <- max(sapply(temp, length)) 
split_padded <- lapply(temp, function(x) {
   length(x) <- max_len
   return(x)
})
tmp <- as.data.frame(do.call(rbind, split_padded), stringsAsFactors = FALSE)
d$temp <- as.numeric(gsub("NA", NA, tmp$V1))

### fixing seed density unit 

d$seed_rate <- d$seed_density <- NA
d$seed_density <- ifelse(grepl("^kg seed/ha$|^seeds/ha$|seed clusters/ha", d$units), d$plant_density,
                         ifelse(grepl("seed/m2|kg seed/m2|grains/m2|seeds/m2|seeds/m",d$units), d$plant_density*10000, d$seed_density))  

d$seed_rate <- ifelse(grepl("kg/ha", d$units), d$plant_density, d$seed_rate)
d$plant_density <- ifelse(grepl("plants/m3|plants/m6|plants/m|plants/m4|plants/m2|plants/m5|plants/m7|hill/m2", d$units), d$plant_density*10000, d$plant_density) 

i <- !is.na(d$seed_density) | !is.na(d$seed_rate)  
d$plant_density[i] <- NA
d$units <- NULL

d$crop_rotation <- gsub("\\|+", ";", d$crop_rotation)

d$treatment_type <- ifelse(grepl("TRUE", d$control_T), "control", "treatment")

### Fixing country
d$country <- ifelse(grepl("Uganda", d$country), "Uganda", 
             ifelse(grepl("Ethiopia", d$country), "Ethiopia", 
             ifelse(grepl("Malawi", d$country), "Malawi", 
             ifelse(grepl("Tanzania", d$country), "Tanzania", 
             ifelse(grepl("Benin..Togo", d$country), "Benin", 
             ifelse(grepl("Ghana..Benin", d$country), "Ghana", 
             ifelse(grepl("Kenya..Kenya", d$country), "Kenya", 
             ifelse(grepl("Drc|Congo", d$country), "Democratic Republic of Congo", d$country))))))))

### Fixing intercrops

split <- strsplit(d$intercrops, "\\*\\*\\*")

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

d$intercrops <- tolower(ifelse(!is.na(inter$V3) & !is.na(inter$V4), paste(inter$V2, inter$V3, inter$V4, sep = ";"), 
                               ifelse(!is.na(inter$V3) & is.na(inter$V4), paste(inter$V2, inter$V3, sep = ";"), inter$V2)))


i <- which(d$K_organic!=0 | d$N_organic!=0 |d$P_organic!=0)
d$OM_used <- FALSE
d$OM_used[i] <- TRUE

#### fixing crop names
crop <- strsplit(d$crop, "-|\\.\\.")
max_len <- max(sapply(crop, length)) 
split_padded <- lapply(crop, function(x) {
   length(x) <- max_len
   return(x)
})
crop <- as.data.frame(do.call(rbind, split_padded), stringsAsFactors = FALSE)
d$crop <- tolower(crop$V1)
P <- carobiner:::fix_name(d$crop)
P <- gsub("tephrosia vogelii", "tephrosia", P)
P <- gsub("macadamia", "macadamia nut", P)
P <- gsub("gliricidia sepium", "gliricidia", P)
P <- gsub("crotalaria grahamiana", "crotalaria", P)
P <- gsub("^fallow", "none", P)
P <- gsub("natural fallow", "none", P)
P <- gsub("bambara nut", "bambara groundnut", P)
P <- gsub("crotalaria spectabilis", "crotalaria", P)
P <- gsub("brachiaria hybrid", "brachiaria", P)
P <- gsub("cooking banana", "banana", P)
P <- gsub("other millet", "millet", P)
P <- gsub("panicum antidotale", "proso millet", P)
P <- gsub("ethiopian eggplant", "eggplant", P)
P <- gsub("passionfruit", "passion fruit", P)
P <- gsub("solanum sp", "eggplant", P)
P <- gsub("urochloa eminii", "congo grass", P)
P <- gsub("fava bean", "faba bean", P)
P <- gsub("tarenna sp", "tarenna", P)
P <- gsub("butter bean", "lima bean", P)
P <- gsub("fluted pumpkin", "pumpkin", P)
P <- gsub("ryegrass sp", "ryegrass", P)
P <- gsub("palm", "oil palm", P)
P <- gsub("sugar cane", "sugarcane", P)
P <- gsub("peas", "pea", P)
P <- gsub("mangifera indica", "mango", P)
P <- gsub("brachiaria brizantha", "brachiaria", P)
P <- gsub("crotalaria ochroleuca", "crotalaria", P)
P <- gsub("purple vetch", "vetch", P)
P <- gsub("crotalaria juncea", "sunn hemp", P)
P <- gsub("gliricidia sp\\.", "gliricidia", P)
P <- gsub("ayocote bean", "runner bean", P)
P <- gsub("brachiaria decumbens", "brachiaria", P)
P <- gsub("helichrysum petiolare", "licorice", P)
P <- gsub("ornithopus sativus", "serradella", P)
P <- gsub("artichokes", "jerusalem artichoke", P)
P <- gsub("acacia sp", "acacia", P)
P <- gsub("acacia auriculiformis", "earleaf acacia", P)
P <- gsub("flemingia sp.", "flemingia", P)
d$crop <- P

## Fixing longitude and latitude 

d$longitude <- sub("(\\d*\\.\\d*?)\\.+", "\\1", d$longitude)## keep only the first decimal point
P <- carobiner::fix_name(d$longitude)
P <- gsub("\\.+$", "", P)
d$longitude <- P
d$longitude <- as.numeric(d$longitude)

d$latitude <- sub("(\\d*\\.\\d*?)\\.+", "\\1", d$latitude)## keep only the first decimal point
P <- carobiner::fix_name(d$latitude)
P <- gsub("\\.+$", "", P)
d$latitude <- P
d$latitude <- as.numeric(d$latitude)



### Fixing Fertilizer

### N
P <- carobiner::fix_name(d$N_fertilizer)
P <- gsub("NA.|.NA", "", P)
P <- gsub("^\\.+", "", P)
P <- gsub("\\.+", " ", P)
d$N_fertilizer <- P

d$N_fertilizer <- ifelse(grepl("999999|999", d$N_fertilizer), NA, d$N_fertilizer)
d$N_fertilizer <- as.numeric(gsub("\\s.*", "", d$N_fertilizer))

### P
P <- carobiner::fix_name(d$P_fertilizer)
P <- gsub("NA.|.NA", "", P)
P <- gsub("^\\.+", "", P)
P <- gsub("\\.+", " ", P)
d$P_fertilizer <- P

d$P_fertilizer <- ifelse(grepl("999999|999", d$P_fertilizer), NA, d$P_fertilizer)
d$P_fertilizer <- as.numeric(gsub("\\s.*", "", d$P_fertilizer))

### K
P <- carobiner::fix_name(d$K_fertilizer)
P <- gsub("NA.|.NA", "", P)
P <- gsub("^\\.+", "", P)
P <- gsub("\\.+", " ", P)
d$K_fertilizer <- P

d$K_fertilizer <- ifelse(grepl("999999|999", d$K_fertilizer), NA, d$K_fertilizer)
d$K_fertilizer <- as.numeric(gsub("\\s.*", "", d$K_fertilizer))


##############################################################
#### Transforming response variable from long into wide format ##########

proc <- function(f, dc){
   
   dc <- dc[dc$dataset_id==f,]
   
   ### Adding  step in the data to facilitate the transformation from long to wide 
   df <- dc %>%
      group_by(variable) %>%
      mutate(id = row_number()) %>%
      ungroup()
   
   df_wide <- df %>%
      pivot_wider(
         id_cols = names(df)[!grepl("value|variable", names(df))],
         names_from = variable ,        
         values_from = value       
      )
   df <- df_wide[order(df_wide$location), ]
   df <- df[, colSums(!is.na(df)) > 0]
   
      
   return(df)
   
}

#### Append the data base on the study (B_code)
ff <- unique(d$dataset_id)
dw <- lapply(ff, function(y) proc(y, d))

dwf <- do.call(carobiner::bindr, dw)

i <- grepl(paste("Crop_Yield", "Soil_Organic_Carbon", "Soil_Total_Nitrogen", "Soil_Nitrogen", "Soil_Organic_Matter", "Carbon_Dioxide_Emissions", "Soil_Organic_Carbon_\\(Change\\)", "CO2_Equivalent_Emissions", "Variable_Cost_per_Unit_Product", "Aboveground_Biomass", "Pest_&_Pathogen_\\(Losses\\)", "Effective_Cation_Exchange_Capacity", "Methane_Emissions", "Nitrous_Oxide_Emissions", "Cation_Exchange_Capacity", "Erosion", "Labour_Cost", "Labour_Person_Hours", "Net_Return", sep = "|"), names(dwf))
names(dwf)[i] <- c("yield","soil_SOC", "soil_total_N", "soil_N", "soil_SOM", "CO2_emission", "soil_ex_SOC", "CO2_eq_emission", "variable_cost", "fwy_total", "pest_severity", "soil_CEC_eff", "CH4_emission", "N2O_emission", "soil_CEC", "soil_erosion", "labour_Cost", "labour", "net_benefit")


### fixing tillage
dwf$land_prep_method <- ifelse(is.na(dwf$land_prep_method) & !is.na(dwf$tillage), dwf$tillage, dwf$land_prep_method)

  ### Fixing land prep 
#dwf$land_prep <- dwf$land_prep_method
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


##### livestock

lvsk <- dwf[which(dwf$product_type=="Animal"),]
dwf <- dwf[!grepl("Animal", dwf$product_type),]


