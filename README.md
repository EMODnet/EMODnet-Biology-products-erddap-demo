
# Create a EMODnet-Biology data product as NetCDF

<!-- badges: start -->
[![Funding](https://img.shields.io/static/v1?label=powered+by&message=emodnet.eu&labelColor=004494&color=ffffff)](http://emodnet.eu/) [![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/EMODnet/EMODnet-Biology-products-erddap-demo/HEAD?urlpath=rstudio)
<!-- badges: end -->

Demo showing how to turn a data frame with biological presences and absences into a four dimensional array and save in a NetCDF file using the R programming language.

Workarounds for when the data is too large to be read into memory at once are shown.

## Demo

The demo can be read online as a HTML document at: 
https://emodnet.github.io/EMODnet-Biology-products-erddap-demo/

If you clone this repository, you can read the demo from: `./demo/demo.Rmd`

If you don't want to download the repository, you can run the demo in a RStudio session that will open in your browser using binder in this link: 
https://mybinder.org/v2/gh/EMODnet/EMODnet-Biology-products-erddap-demo/HEAD?urlpath=rstudio

## Render

To render the html document do:

```r
rmarkdown::render(input = "./demo/demo.Rmd", knit_root_dir = getwd(), output_file = "index.html", output_dir = "./docs/")
```

## Citation

> Fernández-Bejarano, Salvador (2022). Create a EMODnet-Biology data product as NetCDF. Consulted online at https://github.com/EMODnet/EMODnet-Biology-products-erddap-demo on YYYY-MM-DD.

## License

MIT