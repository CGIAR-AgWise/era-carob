    

era_Compiled = function(path){
   
   all_files <- list.files(path)
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
   parquet_file   <- list.files(extract_dir, pattern = "^era_compiled.*\\.parquet$", full.names = TRUE)
   
   ERA_Compiled <- arrow::read_parquet(parquet_file)
   ERA_Compiled
   
}
