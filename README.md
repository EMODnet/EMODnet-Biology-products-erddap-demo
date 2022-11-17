Create a EMODnet-Biology data product as NetCDF
================
@salvafern
2022-11-17

``` r
library(RNetCDF)
library(readr)
library(dplyr)
library(glue)
```

# Read demo data set and explore

This is a fragment of a real data set, adjusted to serve as a small
example. The names of the columns are Darwin Core terms.

See <https://dwc.tdwg.org/terms> in case of doubt.

``` r
dataset <- read_csv("./data/raw/dataset.csv")
```

    ## Rows: 10 Columns: 7
    ## ── Column specification ────────────────────────────────────────────────────────
    ## Delimiter: ","
    ## chr  (2): scientificName, scientificNameID
    ## dbl  (4): decimalLongitude, decimalLatitude, AphiaID, occurrenceStatus
    ## date (1): eventDate
    ## 
    ## ℹ Use `spec()` to retrieve the full column specification for this data.
    ## ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.

``` r
tibble(dataset)
```

    ## # A tibble: 10 × 7
    ##    decimalLongitude decimalLatitude eventDate  scientificName   scientificNameID
    ##               <dbl>           <dbl> <date>     <chr>            <chr>           
    ##  1            -5.70            56.2 2019-06-17 Axinella infund… urn:lsid:marine…
    ##  2            -5.27            51.7 2019-06-17 Axinella infund… urn:lsid:marine…
    ##  3            -5.27            51.7 2019-06-17 Axinella infund… urn:lsid:marine…
    ##  4           -44.2            -24.3 2019-06-17 Pachastrella mo… urn:lsid:marine…
    ##  5           -23.5             14.9 1986-08-22 Pheronema        urn:lsid:marine…
    ##  6           -24.6             15.0 1986-08-24 Pheronema        urn:lsid:marine…
    ##  7             9.62            67.5 2019-06-17 Thenea levis     urn:lsid:marine…
    ##  8            10.3             67.9 2019-06-17 Thenea levis     urn:lsid:marine…
    ##  9             9.52            67.3 2019-06-17 Thenea levis     urn:lsid:marine…
    ## 10            -5.74            57.1 2019-06-17 Axinella infund… urn:lsid:marine…
    ## # … with 2 more variables: AphiaID <dbl>, occurrenceStatus <dbl>

# Arrange dataset

The variable of interest here is `occurrenceStatus`. It has either
presences (1) or absences (0)

This is a variable defined conceptually by 4 dimensions. Spatially,
these are longitude and latitude. Time is also a dimension. A less
common dimension but important for biological data products is taxon of
the biological entity.

The dimensions and the columns in the dataset are shown below. Note the
AphiaID is the unique identifier for a taxon name used in the [World
Record of Marine Species](https://www.marinespecies.org/)

-   Longitude: `decimalLongitude`
-   Latitude: `decimalLatitude`
-   Time: `eventDate`
-   Taxon: `AphiaID`

## Transform time to meet NetCDF constrains

The eventDate must be transformed to temporal amounts. These are
seconds, days, years etc since a certain date There is a helper function
to do this in the RNetCDF package: `uitinvcal.nc()`

In this demo, the units will be `days since 1970-01-01 00:00:00`. The
date must be passed in a format like: `2019-06-17 00:00:00`

``` r
dataset$time <- utinvcal.nc(
  unitstring = "days since 1970-01-01 00:00:00" , 
  value = as.POSIXct(dataset$eventDate, tz = "UTC")
)

unique(dataset$time)
```

    ## [1] 18064  6077  6079

## Expand the data set to have all possible combinations of the dimensions

The key to transform to netcdf, is that the data must be transformed
into a 4D array. To do that, *all the possible combinations of the
dimensions must be added*, coercing `NA` or empty values in the variable
of interest.

The base function `expand.grid()` allows to pass vectors and create a
data frame with all the possible combinations of those vectors.

``` r
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
longer <- expand.grid(lon = lon, lat = lat, time = time, 
                     aphiaid = taxon$aphiaid, 
                     stringsAsFactors = FALSE)

# Define unique identifier again and merge the variable occurrenceStatus with presences and absences

dataset <- dataset %>%
  select(id, occurrenceStatus)

longer <- longer %>% 
  mutate(
    id = glue("{lon}-{lat}-{time}-{aphiaid}")
  ) %>%
  left_join(dataset) %>%
  select(-id)
```

    ## Joining, by = "id"

``` r
# Save for later
write_csv(longer, "./data/derived/longer.csv")

# Inspect
tibble(longer)
```

    ## # A tibble: 1,200 × 5
    ##       lon   lat  time aphiaid occurrenceStatus
    ##     <dbl> <dbl> <dbl>   <dbl>            <dbl>
    ##  1 -44.2  -24.3  6077  132098               NA
    ##  2 -24.6  -24.3  6077  132098               NA
    ##  3 -23.5  -24.3  6077  132098               NA
    ##  4  -5.74 -24.3  6077  132098               NA
    ##  5  -5.70 -24.3  6077  132098               NA
    ##  6  -5.27 -24.3  6077  132098               NA
    ##  7  -5.27 -24.3  6077  132098               NA
    ##  8   9.52 -24.3  6077  132098               NA
    ##  9   9.62 -24.3  6077  132098               NA
    ## 10  10.3  -24.3  6077  132098               NA
    ## # … with 1,190 more rows

## Transform into a 4D array

NetCDF host basically arrays. Transforming into an array will allow the
easiest way to add data into a NetCDF file.

In the demo dataset, we know that the total length of each dimension
are: \* lon: 10 \* lat: 10 \* time: 3 \* taxa: 4

These are important to define the length of each dimension. Also means
that the total length of the variable of interest, in this case
`occurrenceStatus` which contains presences and absences, is all the
possible combinations, hence is:

``` r
10 * 10 * 3 * 4
```

    ## [1] 1200

Which is the total row number of `longer`

``` r
nrow(longer)
```

    ## [1] 1200

To create the array, we pass the variable of interest and the length of
the dimensions:

``` r
array <- array(
  data = longer$occurrenceStatus,
  dim = c(10, 10, 3, 4)
)
```

However, note that this won’t always be possible as adding all the
possible combinations makes the number of rows in a data frame grow
exponentially. Workarounds are discussed later.

# Transform into NetCDF

The first step is to create a netcdf file that will work as a
placeholder to add the data. We use the R package `RNetCDF`

``` r
# Create nc file
nc <- create.nc("./data/derived/foo.nc") 
```

## Define dimensions

Each dimensions has a variable of the same name assigned and a number of
attributes. This is a technical requirement. The dimensions must have
the length of the unique values of each dimension.

Some extra attributes must be added to meet the CF-Convention.

### Longitude

``` r
dim.def.nc(nc, dimname = "lon", dimlength = length(lon)) 
var.def.nc(nc, varname = "lon", vartype = "NC_DOUBLE", dimensions = "lon")
att.put.nc(nc, variable = "lon", name = "units", type = "NC_CHAR", value = "degrees_east")
att.put.nc(nc, variable = "lon", name = "standard_name", type = "NC_CHAR", value = "longitude")
att.put.nc(nc, variable = "lon", name = "long_name", type = "NC_CHAR", value = "Longitude")
```

### Latitude

``` r
dim.def.nc(nc, dimname = "lat", dimlength = length(lat)) 
var.def.nc(nc, varname = "lat", vartype = "NC_DOUBLE", dimensions = "lat")
att.put.nc(nc, variable = "lat", name = "units", type = "NC_CHAR", value = "degrees_north")
att.put.nc(nc, variable = "lat", name = "standard_name", type = "NC_CHAR", value = "latitude")
att.put.nc(nc, variable = "lat", name = "long_name", type = "NC_CHAR", value = "Latitude")
```

### Time

``` r
dim.def.nc(nc, dimname = "time", dimlength = length(time)) 
var.def.nc(nc, varname = "time", vartype = "NC_DOUBLE", dimensions = "time")
att.put.nc(nc, variable = "time", name = "standard_name", type = "NC_CHAR", value = "time")
att.put.nc(nc, variable = "time", name = "long_name", type = "NC_CHAR", value = "Time")
att.put.nc(nc, variable = "time", name = "units", type = "NC_CHAR", value = "days since 1970-01-01 00:00:00")
att.put.nc(nc, variable = "time", name = "_FillValue", type = "NC_DOUBLE", value = -9999.9)
```

### Taxon

There is one dimension called aphiaid, but three variables for this
dimension: \* aphiaid: the actual aphiaid as an integer \* taxon_name:
the name of the taxa \* taxon_lsid: the LSID (unique identifier) of the
taxa

These are technical requirements both for ERDDAP and to meet the
CF-Convention

Note that character variables in NetCDF require to be defined also by a
dimension typically called “string”. Its length is the total number of
characters that can be hosted in the variable of type character. This is
a requirement of NetCDF4.

``` r
# Define the aphia and string80 dimensions
dim.def.nc(nc, dimname = "aphiaid", dimlength = nrow(taxon))
dim.def.nc(nc, dimname = "string80", dimlength = 80)

# Add aphiaid, taxon_name and taxon_lsid variables
var.def.nc(nc, varname = "aphiaid", vartype = "NC_INT", dimensions = "aphiaid")
att.put.nc(nc, variable = "aphiaid", name = "units", type = "NC_CHAR", value = "level")
att.put.nc(nc, variable = "aphiaid", name = "long_name", type = "NC_CHAR", value = "Life Science Identifier - World Register of Marine Species")

var.def.nc(nc, varname = "taxon_name", vartype = "NC_CHAR", dimension = c("string80", "aphiaid"))
att.put.nc(nc, variable = "taxon_name", name = "standard_name", type = "NC_CHAR", value = "biological_taxon_name")
att.put.nc(nc, variable = "taxon_name", name = "long_name", type = "NC_CHAR", value = "Scientific name of the taxa")

var.def.nc(nc, varname = "taxon_lsid", vartype = "NC_CHAR", dimension = c("string80", "aphiaid"))
att.put.nc(nc, variable = "taxon_lsid", name = "standard_name", type = "NC_CHAR", value = "biological_taxon_lsid")
att.put.nc(nc, variable = "taxon_lsid", name = "long_name", type = "NC_CHAR", value = "Life Science Identifier - World Register of Marine Species")
```

### Coordinate Reference System

We will define a non-dimensional variable to host all the info about the
Coordinate Reference System (CRS). This is useful for some GIS software.

Assumed that the CRS is WGS84. If different: transform `decimalLatitude`
and `decimalLongitude` to WGS84 before hand. See R package `sf`.

``` r
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
```

### Put data in the 1D variables

Each variable defining the dimensions must have their own data in. The
data is passed as a 1D vector to `var.put.nc`, specifying in which
variable has to be written.

``` r
# Longitude
var.put.nc(nc, variable = "lon", data = lon) 

# Latitude
var.put.nc(nc, variable = "lat", data = lat) 

# Time
var.put.nc(nc, variable = "time", data = time)

# Taxa
var.put.nc(nc, variable = "aphiaid", data = taxon$aphiaid)
var.put.nc(nc, variable = "taxon_name", data = taxon$taxon_name)
var.put.nc(nc, variable = "taxon_lsid", data = taxon$taxon_lsid)
```

### Add the presence absence variable

The variable to add the presence/absence data must be defined by the
four dimensions considered in this demo. This is passed to
`var.def.nc()` in the argument `dimensions` as a vector containing the
names of the dimensions.

The values stating presences and absences are 1 and 0, hence the
variable must be of type integer.

Some other attributes are added. E.g. `_FillValue` is a requirement for
the CF-Convention stating what value will be used in case of NULL or NA.
This is typically -99999. The attribute `long_name` is free text and it
usually describes the variable. `standard_name`.

``` r
var.def.nc(nc, varname = "presence_absence", vartype = "NC_INT", dimensions = c("lon", "lat", "time", "aphiaid"))
att.put.nc(nc, variable = "presence_absence", name = "_FillValue", type = "NC_INT", value = -99999)
att.put.nc(nc, variable = "presence_absence", name = "long_name", type = "NC_CHAR", value = "Probability of occurrence of biological entity")
```

If there were a standard name for such a variable in the CF-Convention,
this would be add to a new attribute

### Put data in the 4D variable containing presences and absences

This is the most difficult data to add. As we previously created a 4D
array, we can pass this directly to `var.put.nc()`

``` r
var.put.nc(nc, variable = "presence_absence", data = array) 
```

Adding the data from a data set or a vector is also possible by using
the `parameters in`var.put.nc()\` \* In start, each number indicates the
index from which you start adding data for each variable \* In count,
each number indicates the length of the data added for each variable

In this demo, as we have a 4D variable, the vectors will be of length 4.
We can add all the data at once by setting each start index as 1, and
count as the length of each dimension. Remember the length of lon is 10,
lat is 10, time is 3 and taxon is 4. `start` is set as c(1, 1, 1, 1) as
we add all the date from the beginning of each dimension.

``` r
var.put.nc(nc, variable = "presence_absence", 
           data = longer$occurrenceStatus, 
           start = c(1, 1, 1, 1), 
           count = c(10, 10, 3, 4)) 
```

However, out in the wild the data product will become very large when
adding all possible combinations of the dimensions. See how a dataset of
only 10 rows exploded up to 1200 rows when adding all possible
combinations of the four dimensions

``` r
nrow(dataset)
```

    ## [1] 10

``` r
nrow(longer)
```

    ## [1] 1200

Typically you won’t have enough memory in your computer to create a
large array. To work around this issue, you can add data in chunks by
setting correctly `start` and `count`

For instance, you can loop over the data to add one taxon per iteration.
The total number of taxons is 4. Note that the last element of start is
set as `i`, which is the length of the dim aphiaid: 1 to 4

The last element of count corresponds to the count of aphiaid. It is set
as 1 because in each iteration only the data of one taxon is put in the
variable.

``` r
for(i in 1:4){
  
  taxa_i <- taxon$aphiaid[i]
  
  data_at_taxa_i <- subset(longer, longer$aphiaid == taxa_i)
  
  var.put.nc(nc, variable = "presence_absence", data = data_at_taxa_i$occurrenceStatus, start = c(1, 1, 1, i), count = c(10, 10, 3, 1)) 
  
}
```

Furthermore, you can nest loops as much as you want to add the slice of
data that you can handle at once. Below there is an extreme example of a
four times nested loop, in which in each iteration only one data is put
into the NetCDF file.

Remember to use the length of each dimension in the for loop. Note that
`count` is set as `c(1, 1, 1, 1)` as only one data point is added in
each iteration. The argument `start` contains the index of each loop.

``` r
for(loni in 1:10){
  for(lati in 1:10){
    for(timei in 1:3){
      for(taxai in 1:4){
        
        # Read only one row per iteration
        data_at_i <- longer %>%
          filter(
            aphiaid == taxon$aphiaid[taxai],
            time == time[timei],
            lat == lat[lati],
            lon == lon[loni]
          )
        
        # Put the data into 
        var.put.nc(nc, variable = "presence_absence", 
                   data = data_at_i$occurrenceStatus, 
                   start = c(loni, lati, timei, taxai), 
                   count = c(1, 1, 1, 1)) 
      }
    }
  }
}
```

Note this is an extreme example and its performance is not optimal.

These loops are specially useful to turn large amounts of data into
NetCDF as you can have your data saved locally and iterate to read a
certain part of it and put into netcdf at a time.

In next and last example, it is assumed that the data is too large to be
read into memory. In this case, we can write a loop that reads the chunk
of data that we know that R can handle, inmediately put it in the NetCDF
file, and once it is saved there as NetCDF simply remove.

You can read chunks of data from a `.csv` file either with
`readr::read_csv_chunked` or `sqldf::read.csv.sql`. We will use the
first in this example. Remember we saved the `longer` data frame into
`./data/derived/longer.csv`.

``` r
for(i in 1:4){
  
  # Identify the taxa of interest based on the i index
  taxa_i <- taxon$aphiaid[i]
  
  # Read a chunk of data, subsetting to only the taxa of interest in each iteration
  suppressMessages(
    data_at_taxa_i <- read_csv_chunked('./data/derived/longer.csv', 
                                       callback = DataFrameCallback$new(function(x, pos) subset(x, aphiaid == taxa_i)))
  )
  
  # Put the data into the NetCDF file
  var.put.nc(nc, variable = "presence_absence", data = data_at_taxa_i$occurrenceStatus, start = c(1, 1, 1, i), count = c(10, 10, 3, 1)) 
  
  # Inmediately remove the dataset read in the iteration to free memory
  rm(data_at_taxa_i)
}
```

## Wrapping up

Congratulations! The NetCDF file containing the product has been
created. Now you can inspect the file.

``` r
sync.nc(nc)
print.nc(nc)
```

    ## netcdf classic {
    ## dimensions:
    ##  lon = 10 ;
    ##  lat = 10 ;
    ##  time = 3 ;
    ##  aphiaid = 4 ;
    ##  string80 = 80 ;
    ## variables:
    ##  NC_DOUBLE lon(lon) ;
    ##      NC_CHAR lon:units = "degrees_east" ;
    ##      NC_CHAR lon:standard_name = "longitude" ;
    ##      NC_CHAR lon:long_name = "Longitude" ;
    ##  NC_DOUBLE lat(lat) ;
    ##      NC_CHAR lat:units = "degrees_north" ;
    ##      NC_CHAR lat:standard_name = "latitude" ;
    ##      NC_CHAR lat:long_name = "Latitude" ;
    ##  NC_DOUBLE time(time) ;
    ##      NC_CHAR time:standard_name = "time" ;
    ##      NC_CHAR time:long_name = "Time" ;
    ##      NC_CHAR time:units = "days since 1970-01-01 00:00:00" ;
    ##      NC_DOUBLE time:_FillValue = -9999.9 ;
    ##  NC_INT aphiaid(aphiaid) ;
    ##      NC_CHAR aphiaid:units = "level" ;
    ##      NC_CHAR aphiaid:long_name = "Life Science Identifier - World Register of Marine Species" ;
    ##  NC_CHAR taxon_name(string80, aphiaid) ;
    ##      NC_CHAR taxon_name:standard_name = "biological_taxon_name" ;
    ##      NC_CHAR taxon_name:long_name = "Scientific name of the taxa" ;
    ##  NC_CHAR taxon_lsid(string80, aphiaid) ;
    ##      NC_CHAR taxon_lsid:standard_name = "biological_taxon_lsid" ;
    ##      NC_CHAR taxon_lsid:long_name = "Life Science Identifier - World Register of Marine Species" ;
    ##  NC_CHAR crs ;
    ##      NC_CHAR crs:long_name = "Coordinate Reference System" ;
    ##      NC_CHAR crs:geographic_crs_name = "WGS 84" ;
    ##      NC_CHAR crs:grid_mapping_name = "latitude_longitude" ;
    ##      NC_CHAR crs:reference_ellipsoid_name = "WGS 84" ;
    ##      NC_CHAR crs:prime_meridian_name = "Greenwich" ;
    ##      NC_DOUBLE crs:longitude_of_prime_meridian = 0 ;
    ##      NC_DOUBLE crs:semi_major_axis = 6378137 ;
    ##      NC_DOUBLE crs:semi_minor_axis = 6356752.31424518 ;
    ##      NC_DOUBLE crs:inverse_flattening = 298.257223563 ;
    ##      NC_CHAR crs:spatial_ref = "GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563]],PRIMEM["Greenwich",0],UNIT["degree",0.0174532925199433,AUTHORITY["EPSG","9122"]],AXIS["Latitude",NORTH],AXIS["Longitude",EAST],AUTHORITY["EPSG","4326"]]" ;
    ##      NC_CHAR crs:GeoTransform = "-180 0.08333333333333333 0 90 0 -0.08333333333333333 " ;
    ##  NC_INT presence_absence(lon, lat, time, aphiaid) ;
    ##      NC_INT presence_absence:_FillValue = -99999 ;
    ##      NC_CHAR presence_absence:long_name = "Probability of occurrence of biological entity" ;
    ## }

You can read the variables you have created with `var.get.nc`

``` r
# Get variable, turn array into vector and get unique values
unique(c(var.get.nc(nc, variable = "presence_absence")))
```

    ## [1] NA  0  1

If everything is correct, close the file. Remember it was saved into
`./data/derived/foo.nc`

``` r
close.nc(nc)
```
