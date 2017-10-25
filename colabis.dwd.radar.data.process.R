# wps.des: colabis.dwd.radar.data.process, title = COLABIS DWD Radar Data Process, abstract= Enriches input features with DWD Radolan values.;

#wps.in: features, type = application/x-zipped-shp, title = Feature locations,
# abstract = Features that will be enriched, minOccurs = 1, maxOccurs=1;

#wps.in: product, type = string, title = Product type,
# abstract = Radolan product type, minOccurs = 0, maxOccurs=1, value = RX;

library(xtruso)

#wps.off;

features = "d:/data/colabis/sample-points-wgs84.shp"

product = "RX"

#wps.on;

cat(features)

layername <- sub(".shp","", features) # just use the file name as the layer name
cat(layername)
#layername = "sample-points-wgs84"
inputFeatures <- readOGR(features, layer = layername)

filename <- paste("raa01-", tolower(product), "_10000-latest-dwd---bin", sep = "")

sensor <- "radolan"

if(toupper(product) == "RX"){
  sensor <- "composit"
}

url <- paste("https://opendata.dwd.de/weather/radar/", sensor ,"/", tolower(product), "/", filename, sep = "")

download.file(url, destfile = paste("./", filename, sep = ""))

rastersf = ReadRadolanBinary(filename, toupper(product))

#reproject
sr <- "+proj=longlat +datum=WGS84 +no_defs"

projected_raster <- projectRaster(rastersf, crs = sr)

#writeRaster(projected_raster, "d:/tmp/output.tiff", overwrite=TRUE)

x <- numeric()
y <- numeric()
value <- numeric()

dataFrame <- data.frame(x, y, value)

for(i in 1:nrow(inputFeatures)) {
  p <- inputFeatures[i,]
  radarValue = extract(projected_raster, matrix(c(p@coords[1], p@coords[2]), ncol = 2))
  cat(radarValue)
  newRow <- data.frame(x = p@coords[1], y = p@coords[2], value = radarValue)
  dataFrame <- rbind(dataFrame, newRow)
}

#wps.out: id = result, type = text/csv, title = CSV output data;

result <- "./result.csv"

write.csv(dataFrame, file = result)

