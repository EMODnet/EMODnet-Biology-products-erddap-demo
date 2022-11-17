library(RNetCDF)
library(readr)
library(dplyr)
library(glue)

# Read demo dataset and explore
dataset <- read_csv("./data/raw/dataset.csv")
View(dataset)


## ARRANGE DATASET

# The variable of interest here is occurrenceStatus. It has either presences (1) or absences (0)

# This is a variable defined by 4 dimensions:
# decimalLongitude
# decimalLatitude
# time
# taxon

# The eventDate must be transformed to temporal amounts. These are seconds, days, years etc since a certain date
# There is a helper function to do this in the RNetCDF package: uitinvcal.nc()
# In this demo, the units will be "days since 1970-01-01 00:00:00"
# The date must be passed as a format like: 2019-06-17 00:00:00
dataset$time <- utinvcal.nc(
  unitstring = "days since 1970-01-01 00:00:00" , 
  value = as.POSIXct(dataset$eventDate, tz = "UTC")
)


# The key to transform to netcdf, is that the data must be transformed into a 4D array. 
# To do that, all the possible combinations of the dimensions must be added, coercing NA or empty values in the variable of interest
# First add an unique identifier by the combination of:decimaLongitude, decimalLatitude, eventDate and AphiaID
dataset <- dataset %>%
  mutate(
    id = glue("{decimalLongitude}-{decimalLatitude}-{time}-{AphiaID}")
  )

# Extract the unique and sorted values of the 4 dimensions
lon = sort(unique(dataset$decimalLongitude))
lat = sort(unique(dataset$decimalLatitude))
time = sort(unique(dataset$time))

# Taxon will be put in a new data frame so it can be joined afterwards
taxon <- tibble(
  aphiaid = dataset$AphiaID,
  taxon_name = dataset$scientificName,
  taxon_lsid = dataset$scientificNameID) %>% 
  distinct() %>%
  arrange(aphiaid)


# Use expand.grid() to create a data frame with all the possible combinations of the 4 dimensions
array <- expand.grid(lon = lon, lat = lat, time = time, aphiaid = taxon$aphiaid, stringsAsFactors = FALSE)

# Join the other values of taxon, define unique identifier again and merge the variable occurrenceStatus 
# with presences and absences

dataset <- dataset %>%
  select(id, occurrenceStatus)

array <- array %>% 
  left_join(taxon) %>%
  mutate(
    id = glue("{lon}-{lat}-{time}-{aphiaid}")
  ) %>%
  left_join(dataset) %>%
  select(-id)





## TRANSFORM INTO NETCDF

# Create nc file
nc <- create.nc("./data/derived/foo.nc") 

# Define dimensions
# Each dimensions has a variable of the same name assigned and a number of attributes. This is a technical requirement
# The dimensions must have the length of the unique values of each dimension

# Longitude
dim.def.nc(nc, dimname = "lon", dimlength = length(lon)) 
var.def.nc(nc, varname = "lon", vartype = "NC_DOUBLE", dimensions = "lon")
att.put.nc(nc, variable = "lon", name = "units", type = "NC_CHAR", value = "degrees_east")
att.put.nc(nc, variable = "lon", name = "standard_name", type = "NC_CHAR", value = "longitude")
att.put.nc(nc, variable = "lon", name = "long_name", type = "NC_CHAR", value = "Longitude")

# Latitude
dim.def.nc(nc, dimname = "lat", dimlength = length(lat)) 
var.def.nc(nc, varname = "lat", vartype = "NC_DOUBLE", dimensions = "lat")
att.put.nc(nc, variable = "lat", name = "units", type = "NC_CHAR", value = "degrees_north")
att.put.nc(nc, variable = "lat", name = "standard_name", type = "NC_CHAR", value = "latitude")
att.put.nc(nc, variable = "lat", name = "long_name", type = "NC_CHAR", value = "Latitude")

# Time
dim.def.nc(nc, dimname = "time", dimlength = length(time)) 
var.def.nc(nc, varname = "time", vartype = "NC_DOUBLE", dimensions = "time")
att.put.nc(nc, variable = "time", name = "standard_name", type = "NC_CHAR", value = "time")
att.put.nc(nc, variable = "time", name = "long_name", type = "NC_CHAR", value = "Time")
att.put.nc(nc, variable = "time", name = "units", type = "NC_CHAR", value = "days since 1970-01-01 00:00:00")
att.put.nc(nc, variable = "time", name = "_FillValue", type = "NC_DOUBLE", value = -9999.9)

# Taxon: there is one dimension called aphiaid, but three variables for this dimension: 
# one with the actual aphiaid
# one with the name of the taxa
# one with the LSID (unique identifier) of the taxa
dim.def.nc(nc, dimname = "aphiaid", dimlength = nrow(taxon))
dim.def.nc(nc, dimname = "string80", dimlength = 80)

var.def.nc(nc, varname = "aphiaid", vartype = "NC_INT", dimensions = "aphiaid")
att.put.nc(nc, variable = "aphiaid", name = "units", type = "NC_CHAR", value = "level")
att.put.nc(nc, variable = "aphiaid", name = "long_name", type = "NC_CHAR", value = "Life Science Identifier - World Register of Marine Species")

var.def.nc(nc, varname = "taxon_name", vartype = "NC_CHAR", dimension = c("string80", "aphiaid"))
att.put.nc(nc, variable = "taxon_name", name = "standard_name", type = "NC_CHAR", value = "biological_taxon_name")
att.put.nc(nc, variable = "taxon_name", name = "long_name", type = "NC_CHAR", value = "Scientific name of the taxa")

var.def.nc(nc, varname = "taxon_lsid", vartype = "NC_CHAR", dimension = c("string80", "aphiaid"))
att.put.nc(nc, variable = "taxon_lsid", name = "standard_name", type = "NC_CHAR", value = "biological_taxon_lsid")
att.put.nc(nc, variable = "taxon_lsid", name = "long_name", type = "NC_CHAR", value = "Life Science Identifier - World Register of Marine Species")

# Coordinate Reference System: useful for certain GIS software to read netcdf files
# Assumed that the CRS is WGS84. If different: transform decimalLatitude and decimalLongitude to WGS84
var.def.nc(nc, varname = "crs", vartype = "NC_CHAR", dimensions = NA)
att.put.nc(nc, variable = "crs", name = "long_name", type = "NC_CHAR", value = "Coordinate Reference System")
att.put.nc(nc, variable = "crs", name = "geographic_crs_name", type = "NC_CHAR", value = "WGS 84")
att.put.nc(nc, variable = "crs", name = "grid_mapping_name", type = "NC_CHAR", value = "latitude_longitude")
att.put.nc(nc, variable = "crs", name = "reference_ellipsoid_name", type = "NC_CHAR", value = "WGS 84")
att.put.nc(nc, variable = "crs", name = "prime_meridian_name", type = "NC_CHAR", value = "Greenwich")
att.put.nc(nc, variable = "crs", name = "longitude_of_prime_meridian", type = "NC_DOUBLE", value = 0.)
att.put.nc(nc, variable = "crs", name = "semi_major_axis", type = "NC_DOUBLE", value = 6378137.)
att.put.nc(nc, variable = "crs", name = "semi_minor_axis", type = "NC_DOUBLE", value = 6356752.314245179)
att.put.nc(nc, variable = "crs", name = "inverse_flattening", type = "NC_DOUBLE", value = 298.257223563)
att.put.nc(nc, variable = "crs", name = "spatial_ref", type = "NC_CHAR", value = 'GEOGCS[\"WGS 84\",DATUM[\"WGS_1984\",SPHEROID[\"WGS 84\",6378137,298.257223563]],PRIMEM[\"Greenwich\",0],UNIT[\"degree\",0.0174532925199433,AUTHORITY[\"EPSG\",\"9122\"]],AXIS[\"Latitude\",NORTH],AXIS[\"Longitude\",EAST],AUTHORITY[\"EPSG\",\"4326\"]]')
att.put.nc(nc, variable = "crs", name = "GeoTransform", type = "NC_CHAR", value = '-180 0.08333333333333333 0 90 0 -0.08333333333333333 ')


# Check the structure until now
print.nc(nc)


# Put the data in the variables
var.put.nc(nc, variable = "lon", data = lon) 
var.put.nc(nc, variable = "lat", data = lat) 
var.put.nc(nc, variable = "time", data = time)
var.put.nc(nc, variable = "aphiaid", data = taxon$aphiaid)
var.put.nc(nc, variable = "taxon_name", data = taxon$taxon_name)
var.put.nc(nc, variable = "taxon_lsid", data = taxon$taxon_lsid)

# Add the presence absence variable
var.def.nc(nc, varname = "presence_absence", vartype = "NC_INT", dimensions = c("lon", "lat", "time", "aphiaid"))
att.put.nc(nc, variable = "presence_absence", name = "_FillValue", type = "NC_INT", value = -99999)
att.put.nc(nc, variable = "presence_absence", name = "long_name", type = "NC_CHAR", value = "Probability of occurrence of biological entity")

# Add the data
# This is the most difficult data to add
# You can either convert the data into an array and put the data
new_array <- array(
  data = array$occurrenceStatus,
  dim = c(10, 10, 3, 4)
)
var.put.nc(nc, variable = "presence_absence", data = new_array) 


# However, in the wild you will have a large amount of data. 
# Typically you won't have enough memory in your computer to create a large array. 
# You can add data in slices using the start and count parameters
# These are vectors of the length equal to the number of dimensons of the variable.
# In this demo, as we have a 4D variable, the vectors will be of length 4
# In start, each number indicates the index from which you start adding data for each variable
# In count, each number indicates the length of the data added for each variable
# In this demo, we can add all the data at once by setting each start index as 1, and count as the length of each dimension
# count is c(10, 10, 3, 4) because the length of lon is 10, of lat is 10, of time is 3 and of taxon is 4
var.put.nc(nc, variable = "presence_absence", data = array$occurrenceStatus, start = c(1, 1, 1, 1), count = c(10, 10, 3, 4)) 


# In a case where you have too much data to add in one go, you can loop over the start indexes and count.
# e.g., let's put the presence absence data per taxon
# The total number of taxons are 4
# Note that the last element of start is set as `i`, which is the length of the dim aphiaid: 1 to 4
# The last element of count 1, as in each iteration only the data of one taxon is put in the variable
for(i in 1:4){
  
  taxa_i <- taxon$aphiaid[i]
  
  data_at_taxa_i <- subset(array, array$aphiaid == taxa_i)
  
  var.put.nc(nc, variable = "presence_absence", data = data_at_taxa_i$occurrenceStatus, start = c(1, 1, 1, i), count = c(10, 10, 3, 1)) 
  
}

# Equally, you can nest loops to add data at each variable
# The example below shows 4 loops nested to iterate over each data point
# One data is put into the presence absence variable in each iteration
for(loni in 1:10){
  for(lati in 1:10){
    for(timei in 1:3){
      for(taxai in 1:4){
        
        data_at_i <- array %>%
          filter(
            aphiaid == taxon$aphiaid[taxai],
            time == time[timei],
            lat == lat[lati],
            lon == lon[loni]
          )
        
        var.put.nc(nc, variable = "presence_absence", 
                   data = data_at_i$occurrenceStatus, 
                   start = c(loni, lati, timei, taxai), 
                   count = c(1, 1, 1, 1)) 
      }
    }
  }
}


# These loops are specially useful to turn large amounts of data into NetCDF as you can have your data saved locally and iterate to read a certain part of it and put into netcdf at a time.
# E.g. we will save the transformed data array into a csv file and we will read only one taxa at a time, and we will iterate over each taxa to add to the netcdf file
# You can do this either with readr::read_csv_chunked or sqldf::read.csv.sql

write_csv(array, "./data/derived/array.csv")

for(i in 1:4){
  
  taxa_i <- taxon$aphiaid[i]
  
  suppressMessages(
    data_at_taxa_i <- read_csv_chunked('./data/derived/array.csv', 
                                       callback = DataFrameCallback$new(function(x, pos) subset(x, aphiaid == taxa_i)))
  )
  
  var.put.nc(nc, variable = "presence_absence", data = data_at_taxa_i$occurrenceStatus, start = c(1, 1, 1, i), count = c(10, 10, 3, 1)) 
  
  rm(data_at_taxa_i)
}


# Syncronize the file, check and close to save the changes.
sync.nc(nc)
print.nc(nc)

# Quality check
before <- array$occurrenceStatus[complete.cases(array$occurrenceStatus) == TRUE]
after <- c(var.get.nc(nc, "presence_absence"))[complete.cases(c(var.get.nc(nc, "presence_absence"))) == TRUE]
all(before == after)

# End
close.nc(nc)


