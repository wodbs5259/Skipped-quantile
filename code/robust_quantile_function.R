# robust quantile estimation
fit.rob.qt <- function (x, tau = 0.5, w.grid = NULL, sig_type = "MADN", a1 = 2.66, a2 = -2.66, center = NULL, prt = FALSE) {
  
  require(robustbase)
  
  # setting w values for grid search when w.grid is NULL
  if (is.null(w.grid)) w.grid <- 2^(-4:10)
  
  # setting initial values for robust quantile estimation
  m <- ifelse(is.null(center), median(x), center)
  
  # setting variance values for robust quantile estimation
  sig <- ifelse(sig_type == "MADN", mad(x, center = median(x)), mad(x, center = median(x), constant = 1))
  
  # beginning the MM algorithm process
  z <- (x - m)/sig
  
  obj <- sum(rho_a(z, a1 = a1, a2 = a2, tau = tau))
  
  iter <- 1; dif <- Inf
  
  repeat {
    
    if (prt == TRUE) cat(iter, ",", m, "\n")
    
    r <- z - sapply(w.grid, FUN = function(w) psi_a(z, a1 = a1, a2 = a2, tau = tau)/w)
    
    t <- x - r * sig
    
    t.mean.new <- colMeans(t)
    
    z.new <- sapply(t.mean.new, FUN = function(t) (x - t)/sig)
    
    obj.new <- apply(z.new, 2, FUN = function(z) sum(rho_a(z, a1 = a1, a2 = a2, tau = tau)))
    
    idx.w <- which.min(obj.new)
    
    m.new <- t.mean.new[idx.w]
    
    if (abs(obj - obj.new[idx.w])/obj < 1e-8 || iter == 1000) break
    
    m <- m.new; obj <- obj.new[idx.w]; z <- z.new[,idx.w]; iter <- iter + 1
  }
  
  return(list(m = m, iter = iter))
  
}


# robust quantile regression
fit.rob.lin <- function (x, y, tau = 0.5, w.grid = NULL, sig_type = "MADN", a1 = 2.66, a2 = -2.66, prt = FALSE) {
  
  # setting w values for grid search when w.grid is NULL
  if (is.null(w.grid)) w.grid <- 2^(-4:10)
  
  # converting data to a matrix
  if (is.matrix(x) == F) x <- as.matrix(x)
  
  # setting initial values for robust quantile regression
  b <- coef(rq(y ~ x, tau = 0.5))
  
  # calculate residual
  resid <- y - drop(b[1] + x %*% b[-1]) 
  
  # setting variance values for robust quantile regression
  sig <- ifelse(sig_type == "MADN", median(abs(resid))/0.675, median(abs(resid)))
  
  # beginning the MM algorithm process
  z <- resid/sig
  
  obj <- sum(rho_a(z, a1 = a1, a2 = a2, tau = tau))
  
  iter <- 1
  
  repeat {
    
    if (prt == TRUE) cat(iter, ",", b, ",", obj, "\n")
    
    r.mat <- z - sapply(w.grid, FUN = function(w) psi_a(z, a1 = a1, a2 = a2, tau = tau)/w)
    
    b.mat <- apply(r.mat, 2, FUN = function (r) coef(lm(y - r * sig ~ x)))
    
    resid.mat <- apply(b.mat, 2, FUN = function (b) y - drop(b[1] + x %*% b[-1]))
    
    z.mat <- resid.mat / sig
    
    obj.vec <- apply(z.mat, 2, FUN = function (z) sum(rho_a(z, a1 = a1, a2 = a2, tau = tau)))
    
    idx.w <- which.min(obj.vec)
    
    b_new <- b.mat[,idx.w]
    
    obj_new <- obj.vec[idx.w]
    
    if (abs(obj-obj_new) < 1e-4 || iter == 200) break
    
    b <- b_new; obj <- obj_new; z <- z.mat[,idx.w]; iter <- iter + 1
    
  }
  
  return(list(b = b, iter = iter))
  
}


# robust quantile spline regression (Using ns() function)
fit.rob.spline <- function (x, y, tau = 0.5, w.grid = NULL, sig_type = "MADN", a1 = 2.66, a2 = -2.66, df = NULL, prt = FALSE) {
  
  # setting w values for grid search when w.grid is NULL
  if (is.null(w.grid)) w.grid <- 2^(-4:10)
  
  # setting degree of freedom when df is NULL
  if (is.null(df)) df <- smooth.spline(x = x, y = y)$df
  
  # setting initial values for robust quantile spline regression
  b <- coef(rq(y ~ ns(x, df = df), tau = 0.5))
  
  # calculate residual
  resid <- y - (b[1] + b[-1] %*% t(ns(x, df = df)))
  
  # setting variance values for robust quantile spline regression
  sig <- ifelse(sig_type == "MADN", median(abs(resid))/0.675, median(abs(resid)))
  
  # beginning the MM algorithm process
  z <- drop(resid/sig)
  
  obj <- sum(rho_a(z, a1 = a1, a2 = a2, tau = tau))
  
  iter <- 1
  
  repeat {
    
    if (prt == TRUE) cat(iter, ",", b, ",", obj, "\n")
    
    r.mat <- z - sapply(w.grid, FUN = function(w) psi_a(z, a1 = a1, a2 = a2, tau = tau)/w)
    
    b.mat <- apply(r.mat, 2, FUN = function (r) coef(lm((y - r * sig) ~ ns(x, df = df))))
    
    resid.mat <- apply(b.mat, 2, FUN = function (b) y - (b[1] + b[-1] %*% t(ns(x, df = df))))
    
    z.mat <- resid.mat / sig
    
    obj.vec <- apply(z.mat, 2, FUN = function (z) sum(rho_a(z, a1 = a1, a2 = a2, tau = tau)))
    
    idx.w <- which.min(obj.vec)
    
    b_new <- b.mat[,idx.w]
    
    obj_new <- obj.vec[idx.w]
    
    if (abs(obj-obj_new) < 1e-4 || iter == 200) break
    
    b <- b_new; obj <- obj_new; z <- z.mat[,idx.w]; iter <- iter + 1
    
  }
  
  return(list(b = b, iter = iter))
  
}


# integration
fit.rob <- function(data, tau = 0.5, center = NULL, df = NULL, eff = 0.95, sig_type = "MADN", Type = "Estimation"){
  
  clipped_point <- clipped_point(tau = tau, efficiency = eff)
  
  a1 <- clipped_point$a1
  a2 <- clipped_point$a2
  
  # Type = "Estimation" / "linear" / "spline"
  # If Type = "EStimation" is true, data is a vector.
  # If Type = "linear" or "spline" is true, data is data.frame or matrix.
  # And the target variable must be placed in the last column of the data.
  if(Type == "Estimation"){
    
    res <- fit.rob.qt(x = data, a1 = a1, a2 = a2, tau = tau, sig_type = sig_type, center = center)
    
  } else if(Type == "linear") {
    
    res <- fit.rob.lin(x = data[,-ncol(data)], y = data[,ncol(data)],
                       a1 = a1, a2 = a2, tau = tau, sig_type = sig_type)
    
  } else {
    
    res <- fit.rob.spline(x = data[,-ncol(data)], y = data[,ncol(data)],
                          a1 = a1, a2 = a2, tau = tau, df = df, sig_type = sig_type)
    
  }
  
  return(res)
}
