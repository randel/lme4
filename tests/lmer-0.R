require(lme4)
source(system.file("test-tools-1.R", package = "Matrix"))# identical3() etc

## use old (<=3.5.2) sample() algorithm if necessary
if ("sample.kind" %in% names(formals(RNGkind))) {
    suppressWarnings(RNGkind("Mersenne-Twister", "Inversion", "Rounding"))
}

## Check that quasi families throw an error
assertError(lmer(cbind(incidence, size - incidence) ~ period + (1|herd),
		 data = cbpp, family = quasibinomial))
assertError(lmer(incidence ~ period + (1|herd),
		 data = cbpp, family = quasipoisson))
assertError(lmer(incidence ~ period + (1|herd),
		 data = cbpp, family = quasi))

## check bug found by Kevin Buhr
set.seed(7)
n <- 10
X <- data.frame(y=runif(n), x=rnorm(n), z=sample(c("A","B"), n, TRUE))
fm <- lmer(log(y) ~ x | z, data=X)  ## ignore grouping factors with
## gave error inside  model.frame()
stopifnot(all.equal(unname(fixef(fm)), -0.8345, tolerance=.01))

## is "Nelder_Mead" default optimizer?
isNM   <- formals(lmerControl)$optimizer == "Nelder_Mead"
isOldB <- formals(lmerControl)$optimizer == "bobyqa"
## check working of Matrix methods on  vcov(.) etc ----------------------
fm1 <- lmer(Reaction ~ Days + (Days|Subject), sleepstudy)
V  <- vcov(fm)
V1 <- vcov(fm1)
TOL <- 0 # to show the differences below
TOL <- 1e-5 # for the check
stopifnot(
    all.equal(diag(V), if(isNM) 0.176076 else if(isOldB) 0.176068575 else 0.1761714,
              tolerance = TOL)
   ,
    all.equal(as.numeric(chol(V)), if(isNM) 0.4196165 else if(isOldB) 0.41960526 else 0.4197278,
              tolerance=TOL)
   ,
    all.equal(diag(V1), c(46.5639, 2.39), tolerance = 40*TOL)# (for "all" algos)
   ,
    dim(C1 <- chol(V1)) == c(2,2)
   ,
    all.equal(as.numeric(C1),
              c(6.82377, 0, -0.212575, 1.53127), tolerance=20*TOL)# ("all" algos)
   ,
    dim(chol(crossprod(getME(fm1, "Z")))) == 36
  , TRUE)
## printing
signif(chol(crossprod(getME(fm,"Z"))), 4)# -> simple 4 x 4 sparse

showProc.time() #

## From: Stephane Laurent
## To:   r-sig-mixed-models@..
## "crash with the latest update of lme4"
##
## .. example for which lmer() crashes with the last update of lme4 ...{R-forge},
## .. but not with version CRAN version (0.999999-0)
lsDat <- data.frame(
                  Operator = as.factor(rep(1:5, c(3,4,8,8,8))),
                  Part = as.factor(
                  c(2L, 3L, 5L,
                    1L, 1L, 2L, 3L,
                    1L, 1L, 2L, 2L, 3L, 3L, 4L, 5L,
                    1L, 2L, 3L, 3L, 4L, 4L, 5L, 5L,
                    1L, 2L, 2L, 3L, 3L, 4L, 5L, 5L)),
                  y =
                  c(0.34, -1.23, -2.46,
                    -0.84, -1.57,-0.31, -0.18,
                    -0.94, -0.81, 0.77, 0.4, -2.37, -2.78, 1.29, -0.95,
                    -1.58, -2.06, -3.11,-3.2, -0.1, -0.49,-2.02, -0.75,
                    1.71,  -0.85, -1.19, 0.13, 1.35, 1.92, 1.04,  1.08))

xtabs( ~ Operator + Part, data=lsDat) # --> 4 empty cells, quite a few with only one obs.:
##         Part
## Operator 1 2 3 4 5
##        1 0 1 1 0 1
##        2 2 1 1 0 0
##        3 2 2 2 1 1
##        4 1 1 2 2 2
##        5 1 2 2 1 2
lsD29 <- lsDat[1:29, ]

## FIXME: rank-Z test should probably not happen in this case:
(sm3 <- summary(m3 <- lm(y ~ Part*Operator, data=lsDat)))# ok: some interactions not estimable
stopifnot(21 == nrow(coef(sm3)))# 21 *are* estimable
sm4  <- summary(m4 <- lm(y ~ Part*Operator, data=lsD29))
stopifnot(20 == nrow(coef(sm4)))# 20 *are* estimable
lf <- lFormula(y ~ (1|Part) + (1|Operator) + (1|Part:Operator), data = lsDat)
dim(Zt <- lf$reTrms$Zt)## 31 x 31
c(rankMatrix(Zt)) ## 21
c(rankMatrix(Zt,method="qr")) ## 31 ||  29 (64 bit Lnx), then 21 (!)
c(rankMatrix(t(Zt),method="qr")) ## 30, then 21 !
nrow(lsDat)
fm3 <- lmer(y ~ (1|Part) + (1|Operator) + (1|Part:Operator), data = lsDat,
            control=lmerControl(check.nobs.vs.rankZ="warningSmall"))

lf29 <- lFormula(y ~ (1|Part) + (1|Operator) + (1|Part:Operator), data = lsD29)
(fm4 <- update(fm3, data=lsD29))
fm4. <- update(fm4, REML=FALSE)
summary(fm4.)
stopifnot(
    all.equal(as.numeric(formatVC(VarCorr(fm4.))[,"Std.Dev."]),
              c(1.04066, 0.63592, 0.52914, 0.48248), tol = 1e-4)
)


showProc.time()
cat('Time elapsed: ', proc.time(),'\n') # for ``statistical reasons''
