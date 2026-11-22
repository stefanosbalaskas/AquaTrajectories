# No observation rows cannot be silently transformed into spatial occupancy.
test_that("empty canonical trajectories retain zero spatial-zone outputs",{
 source <- data.frame(session_id=character(),camera_id=character(),
     track_id=character(),time_s=numeric(),x=numeric(),y=numeric())
 empty <- aqt_tracks(source,units="cm",coordinate_system="tank")
 z <- data.frame(zone_id="one",xmin=0,xmax=10,ymin=0,ymax=10)
 actual <- aqt_zone_occupancy(empty,z)
 expect_s3_class(actual,"data.frame")
 expect_equal(nrow(actual),0L)
})
test_that("explicit fish_id rather than track_id is accepted without renumbering",{
 source <- data.frame(session_id="S",camera_id="C",
    fish_id=c("009","009"),time_s=c(0,.1),
    x=c(1,2),y=c(2,3),stringsAsFactors=FALSE)
 tr <- aqt_tracks(source)
 expect_identical(tr$track_id,c("009","009"))
 expect_identical(tr$fish_id,c("009","009"))
 expect_identical(attr(tr,"aqt_coordinate_system"),"image")
});
