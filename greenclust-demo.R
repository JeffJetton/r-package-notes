# Fake up some data. Assume that every household with a sale price of
# $250,000 or more wound up buying the product. (But we're not including
# the sale price in the training data.)
library(AmesHousing)
ames <- data.frame(id=ames_raw$PID,
                   year=ames_raw$"Year Built",
                   sqft=ames_raw$"Gr Liv Area",
                   bedrooms=ames_raw$"Bedroom AbvGr",
                   bathrooms=ames_raw$"Full Bath" + ames_raw$"Half Bath"/2,
                   fireplaces=ames_raw$Fireplaces,
                   neighborhood=as.factor(ames_raw$Neighborhood),
                   purchased=as.factor(ifelse(ames_raw$SalePrice >= 250000, "Y", "N")),
                   stringsAsFactors=FALSE)





# We want to build a model to predict a purchase
round(table(ames$purchased)/nrow(ames), 4)



# Take a look at the data set
str(ames)


# Neighborhood might make a good predictor, but there are a lot of levels...
table(ames$neighborhood)





####  Clustering  ####

# First make a contingency table
tab <- table(ames$neighborhood, ames$purchased)
tab

# Create cluster object
library(greenclust)
g <- greenclust(tab)
str(g)

# Standard plot
plot(g)


# Try four clusters...

# Standard tree cutting
clusts <- cutree(g, k=4)
clusts

# Plot clusters at k=4
rect.hclust(g, max(clusts), border=unique(clusts)+1)




####  Helper functions from the package  ####

# greenplot():  "Optimal" clustering is highlighted:
greenplot(g)

# greencut():  Automatically cut the tree at the optimal k
clusts2 <- greencut(g)
clusts2

# Redraw plot at new k clusters
plot(g)
rect.hclust(g, max(clusts2), border=unique(clusts2))

# assign.cluster():  Relate clusters back to original data frame
ames$cluster <- assign.cluster(ames$neighborhood, clusts2)

table(ames$neighborhood, ames$cluster)

round(prop.table(table(ames$cluster, ames$purchase), margin=1), 2)




####  Does it help?  ####

# Single-predictor models: Greenclust clustering vs. "dumb" frequency-based
#                          clustering vs. unclustered levels

# First, add in the frequency-based clusters

# Get frequencies, in order
freqs <- table(ames$neighborhood)
freqs <- freqs[order(freqs, decreasing=TRUE)]
freqs

# Assign order to data set
ames$fclust <- match(ames$neighborhood, names(freqs))

# Keep k the same, for a fair comparison. Lump all but top five together...
ames$fclust <- as.factor(ifelse(ames$fclust > 5, 6, ames$fclust))
table(ames$neighborhood, ames$fclust)

table(ames$fclust)

# Build models...
fit.single <- glm(purchased ~ neighborhood, data=ames, family="binomial")
fit.single.fclust <- glm(purchased ~ fclust, data=ames, family="binomial")
fit.single.gclust <- glm(purchased ~ cluster, data=ames, family="binomial")

summary(fit.single)         # Lots of predictors, many non-significant
summary(fit.single.fclust)  # Fewer predictors, some non-sig
summary(fit.single.gclust)  # Fewer predictors, all significant

# gclust AIC much lower than fclust and even slightly less than using no
# clusters (despite having far fewer predictors!)
fit.single$aic
fit.single.fclust$aic
fit.single.gclust$aic


# Likelihood that fclust is the model that minimizes
# information loss (relative to greenclust model)
aicdiff <- (fit.single.gclust$aic - fit.single.fclust$aic)
exp(aicdiff/2)  # Pretty teensy!

# Relative likelihood that the no-cluster model minimizes
# information loss
aicdiff <- (fit.single.gclust$aic - fit.single$aic)
exp(aicdiff/2)  # Better, but still less than 1


# ROC
library(pROC)

roc.n <- roc(ames$purchased ~ predict(fit.single))
roc.f <- roc(ames$purchased ~ predict(fit.single.fclust))
roc.g <- roc(ames$purchased ~ predict(fit.single.gclust))

# NOTE: These curves are based on same data used for training and
#       will be unrealistically optimistic. Still should be useful
#       for model-to-model comparisons though...

savepar <- par(mfrow=c(1, 3))
plot.roc(roc.n, main="no clustering (28 levels)")
text(0.5, 0, paste("AUC =" , round(roc.n$auc, 3)))
plot.roc(roc.f, main="frequency clustering (6 levels)", col="blue")
text(0.5, 0, paste("AUC =" , round(roc.f$auc, 3)))
plot.roc(roc.g, main="greenclust (6 levels)", col="green")
text(0.5, 0, paste("AUC =" , round(roc.g$auc, 3)))
par(savepar)





####  Does it help, part II: What about a full model?  ####

# Build models...
fit.full <- glm(purchased ~ year + sqft + bedrooms + bathrooms +
                            fireplaces + neighborhood,
                data=ames, family="binomial")
fit.full.fclust <- glm(purchased ~ year + sqft + bedrooms + bathrooms +
                         fireplaces + fclust,
                       data=ames, family="binomial")
fit.full.gclust <- glm(purchased ~ year + sqft + bedrooms + bathrooms +
                         fireplaces + cluster,
                       data=ames, family="binomial")

# Similar relative results for the three models
summary(fit.full)
summary(fit.full.fclust)
summary(fit.full.gclust)

# gclust AIC much lower than fclust and even slightly less than using no
# clusters (despite having far fewer predictors!)
fit.full$aic
fit.full.fclust$aic
fit.full.gclust$aic

# Full model ROCs...

roc.n <- roc(ames$purchased ~ predict(fit.full))
roc.f <- roc(ames$purchased ~ predict(fit.full.fclust))
roc.g <- roc(ames$purchased ~ predict(fit.full.gclust))

savepar <- par(mfrow=c(1, 3))
plot.roc(roc.n, main="no clustering (28 levels)")
text(0.5, 0, paste("AUC =" , round(roc.n$auc, 3)))
plot.roc(roc.f, main="frequency clustering (6 levels)", col="blue")
text(0.5, 0, paste("AUC =" , round(roc.f$auc, 3)))
plot.roc(roc.g, main="greenclust (6 levels)", col="green")
text(0.5, 0, paste("AUC =" , round(roc.g$auc, 3)))
par(savepar)

# Not as big of a difference due to the lower influence of
# the neighborhood predictor in the full model


