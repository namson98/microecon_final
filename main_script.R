
# NFO ---------------------------------------------------------------------

# Final Project.
# Authors: Winkler Soma, Alexandrov Dániel, Nguyen Nam Son
# Date: 16-11-2020

# Setup -------------------------------------------------------------------

if (!require("pacman")) {
  install.packages("pacman")
}

pacman::p_load(AER, haven, ggplot2, dplyr, car, plm, Hmisc,
               stargazer,summarytools, reshape2, Hmisc,
               corrplot,broom, knitr,psych, vars)

wd <- file.path('~', 'microecon_final')
setwd(wd)

df <- read_dta("Bonjour_data.dta")

# Descriptive stats -------------------------------------------------------

dfsum <- df[, c('bweight', 'earning', 'schyear', 'highqua', 'age', 'married', 'full', 'own_exp', 'sm16', 'sm18')] %>%
  dfSummary(., plain.ascii = FALSE, style = "grid", graph.magnif = 0.75, valid.col = FALSE, tmp.img.dir = "/tmp") 


dfsum <- summarise(df, Average = mean(c(age, schyear, highqua, earning, full, married, sm16, sm18), na.rm = T))

# Table of means -------------------------------------------------------

meant<- colMeans(df[, c('bweight', 'earning', 'schyear', 'highqua', 'age', 'married', 'full', 'own_exp', 'sm16', 'sm18')],
                  na.rm = TRUE)
names(meant) <- c('bweight', 'earning', 'schyear', 'highqua', 'age', 'married', 'full', 'own_exp', 'sm16', 'sm18')

#write.table(meant, "~/microecon_final/meant.txt", sep="\t")

#First we create the panel data
pdf <- pdata.frame(df, index = c("family", "twinno"))
pdim(pdf)
View(pdf)

# Differenced variables are created for the within method -----------------

pdf$dhighqua <- diff(pdf$highqua)
pdf$dmarried <- diff(pdf$married)
pdf$dbweight <- diff(pdf$bweight)
pdf$dexp_par <- diff(pdf$exp_par)
pdf$down_exp <- diff(pdf$own_exp)
pdf$dfull <- diff(pdf$full)
pdf$dpart <- diff(pdf$part)
pdf$dself <- diff(pdf$self)
pdf$dsm16 <- diff(pdf$sm16)
pdf$dsm18 <- diff(pdf$sm18)
pdf$logearning <- log(pdf$earning)
pdf$dlogearning <- diff(pdf$logearning)

# Log hourly earnings diff vs estimated years of schooling diff pl --------

coef(lm(dlogearning ~ dhighqua, data = pdf))

diffplot <- ggplot(data = pdf, mapping = aes(x = dhighqua, y = dlogearning)) +
  geom_point(shape = 1) +
  geom_abline(intercept = -0.01424146, slope =  0.03921526, colour = "red") +
  coord_cartesian(xlim = c(-6,6), ylim = c(-2,2)) +
  labs(
    tag = "Figure 1",
    title = "Differences in log earning per hour vs Differences in estimated schooling", 
    y = "Differences in log earning per hour",
    x = "Differences in estimated schooling"
  ) +
  theme_bw()

# Feature Selection -----------------------------------------------------------------



#Correlation matrix

flattenCorrMatrix <- function(cormat, pmat) {
  ut <- upper.tri(cormat)
  data.frame(
    row = rownames(cormat)[row(cormat)[ut]],
    column = rownames(cormat)[col(cormat)[ut]],
    cor  =(cormat)[ut],
    p = pmat[ut]
  )
}

#Basic features

cormatdf <- df[, c('highqua',
                   'bweight',
                   'full',
                   'part',
                   'self',
                   'married',
                   'own_exp',
                   'exp_par')]

res1 <- rcorr(as.matrix(cormatdf))
res11 <- flattenCorrMatrix(res1$r, res1$P)

#write.table(subset(res11, row == 'highqua'), file = "~/microecon_final/res1.txt", sep="\t")

# Insignificant correlations are crossed
corrplot(res1$r, type="upper", order="hclust", p.mat = res1$P, sig.level = 0.05, tl.col = "black", tl.srt = 45)

#Differenced features

cormatdf <- pdf[, c('dhighqua',
                    'dbweight',
                    'dfull',
                    'dpart',
                    'dself',
                    'dmarried',
                    'down_exp',
                    'dexp_par')]

res2 <- rcorr(as.matrix(cormatdf))
res22 <- flattenCorrMatrix(res2$r, res2$P)

#write.table(subset(res22, row == 'dhighqua'), file = "~/microecon_final/res2.txt", sep="\t")

#Insignificant correlation are crossed
corrplot(res2$r, type="upper", order="hclust", p.mat = res2$P, sig.level = 0.05, tl.col = "black", tl.srt = 45)

#Smoking as IV?

cormatdf <- pdf[, c('highqua',
                    'sm16',
                    'sm18')]

res3 <- rcorr(as.matrix(cormatdf))
res33 <- flattenCorrMatrix(res3$r, res3$P)

write.table(subset(res33, row == 'highqua'), file = "~/microecon_final/res3.txt", sep="\t")

# Insignificant correlation are crossed
p3 <- corrplot(res3$r, type="upper", order="hclust", 
               p.mat = res3$P, sig.level = 0.05, tl.col = "black", tl.srt = 45)

#Differencing smoking
cormatdf <- pdf[, c('dhighqua',
                    'dsm16',
                    'dsm18')]

res4 <- rcorr(as.matrix(cormatdf))
res44 <- flattenCorrMatrix(res4$r, res4$P)

#write.table(subset(res44, row == 'dhighqua'), file = "~/microecon_final/res4.txt", sep="\t")

# Insignificant correlation are crossed
p4 <- corrplot(res4$r, type="upper", order="hclust", 
               p.mat = res4$P, sig.level = 0.05, tl.col = "black", tl.srt = 45)

# Methods -----------------------------------------------------------------

#Between method regressions

#Simple OLS regression
ols1 <- lm(log(earning) ~ highqua + age + I(age**2/100), data=df)

#First difference regression with between method
iv1 <- ivreg(log(earning) ~ highqua + age + I(age**2/100) | age + I(age**2/100) + twihigh,  data=df)

#OLS regression with control variables
ols2 <- lm(log(earning) ~ highqua + age + I(age**2/100) + LNandSE + married + own_exp + part + bweight, data=df)

#First difference regression with between method and control variables
iv2 <- ivreg(log(earning) ~ highqua + age + I(age**2/100) + LNandSE + married + own_exp + part + bweight| twihigh + age + I(age**2/100) + LNandSE + married + own_exp + part + bweight,  data=df)

#Panel regressions - within method

#OLS regression 
fdr_ols1 <- plm(log(earning) ~ highqua + age + I(age**2/100), data=pdf, model = 'fd')

#First difference regression 
fdr_iv1 <- plm(log(earning) ~ highqua + age + I(age**2/100) | twihigh + age + I(age**2/100), data=pdf, model = 'fd')

#OLS with control variables
fdr_ols2 <- plm(log(earning) ~ highqua + age + I(age**2/100) + LNandSE + married + own_exp + part + bweight, data=pdf, model = 'fd')

#First difference regression with control variables
fdr_iv2 <- plm(log(earning) ~ highqua + age + I(age**2/100) + LNandSE + married + own_exp + part + bweight | twihigh + age + I(age**2/100) + LNandSE + married + own_exp + part + bweight, data=pdf, model = 'fd')

#comparing all the models together

stargazer(ols1, iv1, ols2, iv2, fdr_ols1, fdr_iv1, fdr_ols2, fdr_iv2, font.size = "small",
          align = TRUE, type = 'text',  out = "models1.htm")

#smoking as IV - test 
ivsm16 <- ivreg(log(earning) ~ highqua + age + I(age**2/100) | age + I(age**2/100) + sm16,  data=df)
ivsm18 <- ivreg(log(earning) ~ highqua + age + I(age**2/100) | age + I(age**2/100) + sm18,  data=df)

stargazer(ols1, ivsm16, ivsm18, type = 'text', out = "models2.htm")

#testing for serial correlation w/ Breusch Godfrey test
pbg <- pbgtest(fdr_iv2, type = "F")

#write.table(pbg, file = "~/microecon_final/pbg.txt", sep="\t")

#####################
#    END OF CODE    #
#####################