# Tests for distribution functions
#
# Author: mjskay
###############################################################################

library(distributional)




# factor distributions ----------------------------------------------------

test_that("distribution functions work on wrapped distributions", {
  expect_equal(distr_pdf(dist_wrap("norm", 1, 2))(-2:2), dnorm(-2:2, 1, 2))
  expect_equal(distr_cdf(dist_wrap("norm", 1, 2))(-2:2), pnorm(-2:2, 1, 2))
  expect_equal(distr_quantile(dist_wrap("norm", 1, 2))(ppoints(5)), qnorm(ppoints(5), 1, 2))
  expect_equal(
    distr_point_interval(dist_wrap("norm", 1, 2), median_qi, trans = scales::identity_trans()),
    tibble(
      .value = 1,
      .lower = qnorm(0.025, 1, 2),
      .upper = qnorm(0.975, 1, 2),
      .width = 0.95,
      .point = "median",
      .interval = "qi"
    )
  )
})


# distributional objects --------------------------------------------------

test_that("distribution functions work on distributional objects", {
  x = dist_normal(1,2)
  expect_equal(distr_pdf(x)(-2:2), dnorm(-2:2, 1, 2))
  expect_equal(distr_cdf(x)(-2:2), pnorm(-2:2, 1, 2))
  expect_equal(distr_quantile(x)(ppoints(5)), qnorm(ppoints(5), 1, 2))

  # with subsetting
  expect_equal(distr_pdf(x[[1]])(-2:2), dnorm(-2:2, 1, 2))
  expect_equal(distr_cdf(x[[1]])(-2:2), pnorm(-2:2, 1, 2))
  expect_equal(distr_quantile(x[[1]])(ppoints(5)), qnorm(ppoints(5), 1, 2))
})


# sample distributions ----------------------------------------------------

test_that("sample distributions can be detected and samples extracted", {
  x = dist_sample(list(1:10))
  expect_equal(distr_is_sample(x), TRUE)
  expect_equal(distr_get_sample(x), 1:10)

  x = vctrs::field(dist_sample(list(1:10)), 1)
  expect_equal(distr_is_sample(x), TRUE)
  expect_equal(distr_get_sample(x), 1:10)

  # RVAR
  skip_if_not_installed("posterior")
  x = posterior::rvar(1:10L)
  expect_equal(distr_is_sample(x), TRUE)
  expect_equal(as.vector(distr_get_sample(x)), 1:10)
  expect_equal(distr_is_discrete(x), TRUE)

  x = posterior::rvar(1:10/2)
  expect_equal(distr_is_discrete(x), FALSE)
})


# constant distributions --------------------------------------------------

test_that("constant distributions are detected correctly", {
  expect_equal(distr_is_constant(dist_normal(0,1)), FALSE)
  expect_equal(distr_is_constant(dist_normal(0,.Machine$double.eps)), FALSE)
  expect_equal(distr_is_constant(dist_normal(0,0)), TRUE)
  expect_equal(distr_is_constant(dist_wrap("lnorm",1,0)), TRUE)
  expect_equal(distr_is_constant(dist_sample(list(1))), TRUE)
  expect_equal(distr_is_constant(dist_sample(list(c(2,2,2)))), TRUE)
  expect_equal(distr_is_constant(dist_sample(list(c(1,2,3)))), FALSE)

  skip_if_not_installed("posterior")
  expect_equal(distr_is_constant(posterior::rvar(1)), TRUE)
  expect_equal(distr_is_constant(posterior::rvar(c(3,3,3))), TRUE)
  expect_equal(distr_is_constant(posterior::rvar(c(1,2,3))), FALSE)
})
