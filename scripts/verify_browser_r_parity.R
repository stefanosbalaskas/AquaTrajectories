# Independently execute the released v0.1.1 R API against JS-produced fixtures.
# The numerical parity comparison does NOT imply empirical underwater accuracy.
args <- commandArgs(trailingOnly=TRUE)
dir <- if(length(args)) args[1L] else "site-qualification/parity"
if(!requireNamespace("aquaTrajectories",quietly=TRUE)) stop("Install the local R package for parity qualification")
ap <- asNamespace("aquaTrajectories")
tol <- 2e-5
same <- function(found,expected,label,tolerance=tol) {
 if(!is.finite(found) || !is.finite(expected) || abs(found-expected)>tolerance)
   stop(sprintf("BROWSER_R_PARITY_FAIL[%s]: %.13f vs %.13f; abs delta %.7g > %.7g",label,found,expected,abs(found-expected),tolerance))
}
geos <- utils::read.csv(file.path(dir,"geometry.csv"),stringsAsFactors=FALSE)
for(i in seq_len(nrow(geos))) {
 g <- geos[i,]
 K <- diag(c(g$focalPx,g$focalPx,1))
 R <- diag(c(1,-1,-1))
 camera <- function(x)ap$aqt_refractive_camera(
   K=K,R_c2w=R,center=c(x,0,g$height),
   plane_point=c(0,0,0),plane_normal=c(0,0,-1),
   n_before=1,n_after=g$nWater,units="cm")
 a <- camera(-g$baseline/2);b <- camera(g$baseline/2)
 to_pixel <- function(x,y,z) {
  h <- as.vector(t(R) %*% c(x,y,z))
  matrix(c(g$focalPx*h[1]/h[3],g$focalPx*h[2]/h[3]),nrow=1L)
 }
 result <- ap$aqt_refractive_triangulate(a,b,
    to_pixel(g$inc1x,g$inc1y,g$inc1z),
    to_pixel(g$inc2x,g$inc2y,g$inc2z))
 if(!identical(result$valid[1L],TRUE))stop("Refractive R abstained on fixture ",g$id)
 for(key in c("x","y","z"))same(result[[key]][1L],g[[paste0("expected",toupper(key))]],paste(g$id,key))
 same(result$separation[1L],g$expectedGap,paste(g$id,"ray gap"))
}
speeds <- utils::read.csv(file.path(dir,"kinematics.csv"),stringsAsFactors=FALSE)
for(i in seq_len(nrow(speeds))) {
 g<-speeds[i,]
 d<-data.frame(session_id=rep("S",2),camera_id=rep("C",2),track_id=rep(g$id,2),
   time_s=c(0,g$dt),x=c(0,g$dx),y=c(0,g$dy))
 actual<-ap$aqt_kinematics(ap$aqt_tracks(d,units="cm",coordinate_system="tank"))
 for(key in c("distance","vx","vy","speed")){
   rkey<-if(key=="distance")"step_distance" else key
   same(actual[[rkey]][2],g[[key]],paste(g$id,key),1e-9)
 }
}
polar <- utils::read.csv(file.path(dir,"polarization.csv"),stringsAsFactors=FALSE)
for(i in seq_len(nrow(polar))) {
 g<-polar[i,]
 angles<-as.numeric(unlist(g[paste0("a",seq_len(g$n))]))
 n<-length(angles)
 d<-data.frame(session_id=rep("S",2*n),camera_id=rep("C",2*n),
  track_id=rep(paste0("f",seq_len(n)),each=2),
  time_s=rep(c(0,1),times=n),x=c(rbind(rep(0,n),cos(angles*pi/180))),
  y=c(rbind(rep(0,n),sin(angles*pi/180))))
 actual<-ap$aqt_group_metrics(ap$aqt_tracks(d,units="cm",coordinate_system="tank"))
 p<-actual$polarization[actual$time_s==1]
 if(length(p)!=1)stop("Wrong school grouping")
 same(p,g$expected,g$id,1e-9)
}
cat("AQT_R_JS_NUMERICAL_PARITY_PASS:",nrow(geos),"refractive,",nrow(speeds),"kinematics,",nrow(polar),"polarization cases; no scientific empirical accuracy claim\n")
