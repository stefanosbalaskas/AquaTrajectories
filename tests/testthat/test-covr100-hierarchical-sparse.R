# Hierarchical models require independent tank replication, not repeated
# observations of a single fish. Dataset is deliberately synthetic.
.cov100_hier_data <- function() {
 d<-expand.grid(tank_id=c("C1","C2","T1","T2"),
        fish_index=1:2,epoch=c("baseline","response"),
        KEEP.OUT.ATTRS=FALSE,stringsAsFactors=FALSE)
 d$camera_id<-"TOP"
 d$track_id<-paste0("F",d$fish_index)
 d$treatment<-ifelse(grepl("^C",d$tank_id),"control","treatment")
 d$value<-2+as.numeric(d$fish_index)*.1+
   ifelse(d$epoch=="response",1,0)+
   ifelse(d$treatment=="treatment"&d$epoch=="response",.3,0)+
   ifelse(d$tank_id %in% c("C2","T2"),.15,0)
 d$fish_index<-NULL
 d
}
test_that("hierarchical event schema explicitly rejects missingness and pseudo-replication", {
 d<-.cov100_hier_data()
 expect_error(aqt_hierarchical_event_prepare(list()),"Expected nonempty")
 expect_error(aqt_hierarchical_event_prepare(d[FALSE,,drop=FALSE]),"Expected nonempty")
 bad<-d;bad$value<-as.character(bad$value)
 expect_error(aqt_hierarchical_event_prepare(bad),"Event values must be finite")
 bad<-d;bad$value[1]<-Inf
 expect_error(aqt_hierarchical_event_prepare(bad),"Event values must be finite")
 bad<-d;bad$tank_id[1]<-""
 expect_error(aqt_hierarchical_event_prepare(bad),"Grouping IDs and epochs|Hierarchical grouping")
 bad<-d;bad$track_id[1]<-NA_character_
 expect_error(aqt_hierarchical_event_prepare(bad),"Hierarchical grouping")
 expect_error(aqt_hierarchical_event_prepare(d,treatment_levels="control"),
              "Two distinct ordered")
 expect_error(aqt_hierarchical_event_prepare(d,treatment_levels=c("control","control")),
              "Two distinct ordered")
 expect_error(aqt_hierarchical_event_prepare(d,epoch_levels=c("baseline","baseline")),
              "Two distinct ordered")
 expect_error(aqt_hierarchical_event_prepare(d,epoch_levels=c("one","two")),
              "Only the two specified event epochs")
 too_few<-d[d$tank_id!="T2",,drop=FALSE]
 expect_error(aqt_hierarchical_event_prepare(too_few),
              "Require two treatment groups and >=2")
 other<-d;other$event_id<-ifelse(other$tank_id=="C1","E1","E2")
 expect_error(aqt_hierarchical_event_prepare(other),
              "Repeated events require a different")
 repeat_row<-rbind(d,d[1,,drop=FALSE])
 expect_error(aqt_hierarchical_event_prepare(repeat_row),
              "Duplicate fish-within-tank epoch")
 missing<-d[-1,,drop=FALSE]
 expect_error(aqt_hierarchical_event_prepare(missing),
              "Each fish requires both")
 valid<-aqt_hierarchical_event_prepare(d)
 expect_s3_class(valid,"aqt_hierarchical_event_frame")
 expect_equal(nlevels(valid$tank_id),4L)
 expect_equal(nlevels(valid$epoch),2L)
 expect_equal(attr(valid,"aqt_design_audit")$n_tanks,c(2L,2L))
 expect_error(aqt_hierarchical_event_fit(list()),
              "Use aqt_hierarchical_event_prepare")
})
test_that("sparse FPCA preparation retains explicit observed ragged source curves", {
 d<-do.call(rbind,lapply(1:6,function(i)data.frame(session_id="S",
   camera_id="C",track_id=paste0("F",i),time_s=0:5,
   x=i+(0:5)*.2,y=(0:5)*i,observed=TRUE)))
 tr<-aqt_tracks(d,units="cm",coordinate_system="tank")
 expect_error(aqt_sparse_fpca_input(tr,coordinate="z"),"Coordinate must")
 expect_error(aqt_sparse_fpca_input(tr,coordinate=c("x","y")),"Coordinate must")
 expect_error(aqt_sparse_fpca_input(tr,min_points=2),"min_points must")
 expect_error(aqt_sparse_fpca_input(tr,min_points=3.5),"min_points must")
 expect_error(aqt_sparse_fpca_input(tr[FALSE,,drop=FALSE]),"No fish trajectories")
 fewer<-tr[tr$track_id %in% paste0("F",1:4),,drop=FALSE]
 expect_error(aqt_sparse_fpca_input(fewer),"requires >=5 scoped curves")
 d$observed[d$track_id=="F1" & d$time_s>=3]<-FALSE
 partial<-aqt_sparse_fpca_input(aqt_tracks(d,units="cm",
            coordinate_system="tank"),min_points=3)
 expect_equal(length(partial$Ly),6L)
 expect_equal(partial$scope$n_observed[partial$scope$track_id=="F1"],3L)
 expect_equal(partial$scope$observed_fraction[
                  partial$scope$track_id=="F1"],.5)
 expect_equal(partial$Lt[[1]][1],0,tolerance=1e-12)
 expect_error(aqt_sparse_fpca_design_audit(list()),"Expected an aqt_sparse_fpca_input")
 expect_error(aqt_sparse_fpca_design_audit(partial,bins=4),"bins must")
 expect_error(aqt_sparse_fpca_design_audit(partial,bins=101),"bins must")
 coverage<-aqt_sparse_fpca_design_audit(partial,bins=5)
 expect_equal(coverage$n_total_curves,rep(6L,5L))
 expect_true(all(coverage$curve_fraction>=0&coverage$curve_fraction<=1))
 dropped<-d
 dropped$observed[dropped$track_id=="F1" & dropped$time_s==2]<-FALSE
 expect_error(aqt_sparse_fpca_input(aqt_tracks(dropped,units="cm",
              coordinate_system="tank"),min_points=3),
              "Insufficient observed samples")
 absolute<-aqt_sparse_fpca_input(tr,time_axis="absolute")
 expect_equal(absolute$Lt[[1]],0:5)
 expect_error(aqt_sparse_fpca_fit(list()),"Expected aqt_sparse_fpca_input")
 expect_error(aqt_sparse_fpca_fit(absolute,optns=3),"optns must")
 expect_error(aqt_sparse_fpca_fit(absolute,optns=list(1)),"optns must")
 if(requireNamespace("fdapace",quietly=TRUE))
   expect_error(aqt_sparse_fpca_fit(absolute,optns=list(dataType="Dense")),
                "dataType and plot are fixed")
})
