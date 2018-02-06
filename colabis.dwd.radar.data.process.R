# wps.des: colabis.dwd.radar.data.process, title = COLABIS DWD Radar Data Process, abstract= Enriches input features with DWD Radolan values.;

#wps.in: features, type = application/x-zipped-shp, title = Feature locations,
# abstract = Features that will be enriched, minOccurs = 1, maxOccurs=1;

#wps.in: product, type = string, title = Product type,
# abstract = Radolan product type, minOccurs = 0, maxOccurs=1, value = RX;

#wps.in: maxNumberOfDatasets, type = integer, title = Maximum number of datasets,
# abstract = The maximum number of datasets that values are gathered from, minOccurs = 0, maxOccurs=1, value = 20;

library(xtruso)
library(stringr)

#wps.off;

features = "d:/data/colabis/sample-points-wgs84.shp"

product = "RX"

maxNumberOfDatasets <- 20

#wps.on;

layername <- sub(".shp","", features) # just use the file name as the layer name

#wps.off;
layername = "sample-points-wgs84"
#wps.on;

inputFeatures <- readOGR(features, layer = layername)

#summary(inputFeatures)

productNameUpperCase <- toupper(product)

productNameLowerCase <- tolower(product)

sensor <- "radolan"

if(toupper(product) == "RX"){
  sensor <- "composit"
}

url <- paste("https://opendata.dwd.de/weather/radar/", sensor ,"/", productNameLowerCase, "/", sep = "")

# read the file listing
pg <- readLines(url)

#head(pg)

# extract filenames from html
pg <- str_replace(pg, "^.*raa01", "raa01")

pg <- pg[ startsWith(pg, "raa01") ]

pg <- str_replace(pg, "</a>.*", "")

pg <- pg[ !endsWith(pg, "latest-dwd---bin") ]

urls <- sprintf("%s%s", url, pg)

#head(urls)

urls2 <- tail(urls, maxNumberOfDatasets + 1)

dir = file.path("/usr/share/data", "opendata.dwd.de/weather/radar/composit/rx");

dir.create(dir, recursive = TRUE)
#setwd(dir)

existingFiles <- list.files(dir)

x <- numeric()
y <- numeric()
value <- numeric()
timeStamp <- character()

dataFrame <- data.frame(x, y, value, timeStamp)

for (f in urls2[-1]) {
  
  #extract base name from link (presumably the part after the last forward slash)
  baseName <- basename(f)
  
  currentTimeStamp <- sub("^.*10000-", "", baseName)
  
  currentTimeStamp <- sub("-dwd.*", "", currentTimeStamp)
  
  if(baseName %in% existingFiles){
    print(paste("Not downloading: ", baseName))
  }else{
    print(paste("Downloading: ", baseName))
    
    fullFilePath <- paste(dir, baseName, sep = "/");
    
    try(download.file(f, paste(dir, baseName, sep = "/")))
  }
}

#re-list files
existingFiles <- list.files(dir)

existingFiles <- tail(existingFiles, maxNumberOfDatasets + 1)

for(existingFile in existingFiles[-1]){
  
  if(! startsWith(existingFile, "raa01")){
    print(paste("Not processing file:", existingFile))
    next
  }
  
  currentTimeStamp <- sub("^.*10000-", "", existingFile)
  
  currentTimeStamp <- sub("-dwd.*", "", currentTimeStamp)
    
  print(paste("Processing: ", paste(dir, existingFile, sep = "/")))
  
  rastersf = ReadRadolanBinary(paste(dir, existingFile, sep = "/"), productNameUpperCase)
  
  #reproject
  sr <- "+proj=longlat +datum=WGS84 +no_defs"
  
  projected_raster <- projectRaster(rastersf, crs = sr)
  
  for(i in 1:nrow(inputFeatures)) {
    p <- inputFeatures[i,]
    radarValue = extract(projected_raster, matrix(c(p@coords[1], p@coords[2]), ncol = 2))
    #cat(radarValue)
    newRow <- data.frame(x = p@coords[1], y = p@coords[2], value = radarValue, timeStamp = currentTimeStamp)
    dataFrame <- rbind(dataFrame, newRow)
  }
  
}

#wps.out: id = result, type = text/csv, title = CSV output data;

result <- "./result.csv"

write.csv(dataFrame, file = result)

