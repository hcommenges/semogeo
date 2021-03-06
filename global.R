##############################
# Shiny App: MOTS-GÉO
# Packages and functions
##############################



# load packages ----

library(shiny)
library(shinythemes)
library(reshape2)
library(igraph)
library(ggplot2)
library(RColorBrewer)
library(dplyr)


# plot communities ----

VisuComm <- function(g, year, comm, vertcol, vertsize, vfacsize, edgesize, efacsize, textsize){

  oriCoords <- layout.circle(g)
  # circle layout with sampled coordinates
  # corrCoords <- oriCoords[sample(seq(from = 1, to = nrow(oriCoords), by = 1),
  #                                size = nrow(oriCoords),
  #                                replace = FALSE), ]

  plot(g,
       main = paste("Communauté \"", comm, "\" - ", year, sep = ""),
       edge.color = "grey70",
       edge.width = efacsize * edgesize,
       edge.curved = F,
       edge.arrow.mode = "-",
       edge.arrow.size = 0.01,
       vertex.shape = "circle",
       vertex.color = vertcol,
       vertex.frame.color = "white",
       vertex.label = V(g)$name,
       vertex.label.color = "black",
       vertex.label.family = "sans-serif",
       vertex.label.cex = textsize / 10,
       vertex.size = vfacsize * vertsize,
       layout = oriCoords
  )
}


# plot ego network ----

VisuEgo <- function(g, year, kw, vertcol, vertlabcol, vertsize, vfacsize, edgesize, textsize){
  
  plot(g,
       main = paste(kw, " - ", year, sep = ""),
       edge.color = "grey60",
       edge.width = edgesize * E(g)$relresid,
       edge.curved = F,
       edge.arrow.mode = "-",
       edge.arrow.size = 0.01,
       vertex.color = vertcol,
       vertex.frame.color = "white",
       vertex.label = V(g)$name,
       vertex.label.color = vertlabcol,
       vertex.label.family = "sans-serif",
       vertex.label.cex = textsize / 10,
       vertex.size = vfacsize * vertsize,
       layout = layout.fruchterman.reingold(g, weights = E(g)$relresid)
  )
}


GetColPal <- function(g){
  colPal <- pal <- c("chocolate",
                     "darkolivegreen",
                     "darkgoldenrod1",
                     "firebrick",
                     "olivedrab", 
                     "darkgoldenrod1", 
                     "yellow3",
                     "lightgoldenrod4", 
                     "darkolivegreen")
  colLim <- colPal[1:length(unique(V(g)$clus))]
  V(g)$clus <- plyr::mapvalues(V(g)$clus, from = sort(unique(V(g)$clus)), to = colLim)
  return(g)
}


# plot semantic field ----

VisuSem <- function(g, year, kw, textsizemin, textsizemax){
  
  # make theme empty
  theme_empty <- theme_bw() +
    theme(axis.line = element_blank(),
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank(),
          panel.border = element_blank(),
          panel.background = element_blank(),
          axis.title = element_blank(),
          axis.text = element_blank(),
          axis.ticks = element_blank(),
          legend.position = "bottom")
  
  # graph layout
  tabPoints <- get.data.frame(x = g, what = "vertices")
  tabLinks <- get.data.frame(x = g, what = "edges")
  tabLinks$NODES <- ifelse(tabLinks$from == kw, tabLinks$to, tabLinks$from)
  tabPoints <- merge(x = tabPoints, y = tabLinks, by.x = "name", by.y = "NODES", all.x = TRUE)
  
  # compute distance from ego
  tabPoints$DIST <- 1 / tabPoints$relresid
  coefCorr <- ifelse(max(tabPoints$DIST, na.rm = TRUE) < 1, 1 / max(tabPoints$DIST, na.rm = TRUE), 1)
  tabPoints$DISTCORR <- tabPoints$DIST * coefCorr
  thresRadis <- seq(0, 0.1 + max(tabPoints$DISTCORR, na.rm = TRUE), 0.1)
  tabPoints$X <- cut(tabPoints$DISTCORR, breaks = thresRadis, labels = thresRadis[-1], include.lowest = TRUE, right = FALSE)
  tabPoints <- tabPoints %>% group_by(X) %>% mutate(NPTS = n())
  
  # get x values
  tabPoints <- tabPoints %>% do(GetXvalues(df = .))
  tabPoints[tabPoints$name == kw, c("XVAL", "DISTCORR")] <- c(0, 0)
  
  # prepare plot
  tabPoints$IDEGO <- ifelse(tabPoints$name == kw, 2, 1)
  tabCircle <- data.frame(XVAL = c(0, 360), DISTCORR = 1)
  
  # draw plot
  circVis <- ggplot() + 
    geom_line(data = tabCircle, aes(x = XVAL, y = DISTCORR), color = "grey20") + 
    geom_text(data = tabPoints, aes(x = XVAL, y = DISTCORR, label = name, fontface = IDEGO, 
                                    color = factor(IDEGO, levels = 1:2, c("Voisins", "Ego")), 
                                    size = nbauth)) +
    scale_colour_manual("Type", values = c("grey50", "grey20")) +
    scale_size_continuous("Number of articles", range = c(textsizemin, textsizemax)) +
    coord_polar(theta = "x") +
    ggtitle(label = paste(kw, year, sep = " - ")) +
    theme_empty
  
  return(circVis)
}


# Internal functions for VisuSem() ----


# Sample x values for polar coordinates

GetXvalues <- function(df){
  initVal <- sample(x = 0:360, size = 1, replace = FALSE)
  tempRange <- seq(initVal, initVal + 360, 360/unique(df$NPTS))
  tempRange <- tempRange[-length(tempRange)]
  df$XVAL <- ifelse(tempRange > 360, tempRange - 360, tempRange) 
  return(df)
}


# create semantic field network

SemanticField <- function(g, kw){
  
  # list of neighbors
  neiNodes <- unlist(neighborhood(g, order = 1, nodes = V(g)[V(g)$name == kw], mode = "all"))
  pairedNodes <- unlist(paste(which(V(g)$name == kw), neiNodes[-1], sep = ","))
  collapseNodes <- paste(pairedNodes, collapse = ",")
  vecNodes <- as.integer(unlist(strsplit(collapseNodes, split = ",")))
  
  # get edges and create graph
  edgeIds <- get.edge.ids(g, vp = vecNodes)
  gSem <- subgraph.edges(g, eids = edgeIds, delete.vertices = TRUE)
  
  return(gSem)
}
