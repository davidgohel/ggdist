# Utility functions for ggdist
#
# Author: mjskay
###############################################################################


# deparse that is guaranteed to return a single string (instead of
# a list of strings if the expression goes to multiple lines)
deparse0 = function(expr, width.cutoff = 500, ...) {
  paste0(deparse(expr, width.cutoff = width.cutoff, ...), collapse = "")
}

stop0 = function(...) {
  stop(..., call. = FALSE)
}

warning0 = function(...) {
  warning(..., call. = FALSE)
}

# get all variable names from an expression
# based on http://adv-r.had.co.nz/dsl.html
all_names = function(x) {
  if (is.atomic(x)) {
    NULL
  } else if (is.name(x)) {
    as.character(x)
  } else if (is.call(x) || is.pairlist(x)) {
    children = lapply(x[-1], all_names)
    unique(unlist(children))
  } else {
    stop0("Don't know how to handle type ", deparse0(typeof(x)))
  }
}

# set missing values from x to provided default values
defaults = function(x, defaults) {
  c(x, defaults[setdiff(names(defaults), names(x))])
}


# deprecations and warnings -----------------------------------------------

#' @importFrom rlang enexprs
.Deprecated_arguments = function(old_names, ..., message = "", which = -1, fun = as.character(sys.call(which))[[1]]) {
  deprecated_args = intersect(old_names, names(enexprs(...)))

  if (length(deprecated_args) > 0) {
    stop0(
      "\nIn ", fun, "(): The `", deprecated_args[[1]], "` argument is deprecated.\n",
      message,
      "See help(\"ggdist-deprecated\").\n"
    )
  }
}

.Deprecated_argument_alias = function(new_arg, old_arg, which = -1, fun = as.character(sys.call(which))[[1]]) {
  if (missing(old_arg)) {
    new_arg
  } else {
    new_name = quo_name(enquo(new_arg))
    old_name = quo_name(enquo(old_arg))

    warning0(
      "\nIn ", fun, "(): The `", old_name, "` argument is a deprecated alias for `",
      new_name, "`.\n",
      "Use the `", new_name, "` argument instead.\n",
      "See help(\"tidybayes-deprecated\") or help(\"ggdist-deprecated\").\n"
    )

    old_arg
  }
}


# workarounds -------------------------------------------------------------

# workarounds / replacements for common patterns

#' @importFrom dplyr bind_rows
map_dfr_ = function(data, fun, ...) {
  # drop-in replacement for purrr::map_dfr
  bind_rows(lapply(data, fun, ...))
}

pmap_ = function(data, fun) {
  # this is roughly equivalent to purrr::pmap
  lapply(vctrs::vec_chop(data), function(row) do.call(fun, lapply(row, `[[`, 1)))
}

pmap_dfr_ = function(data, fun) {
  # this is roughly equivalent to
  # pmap_dfr(df, function(...) { ... })
  # but works properly with vctrs (pmap_dfr seems broken on rvars?)
  bind_rows(pmap_(data, fun))
}

ddply_ = function(data, groups, fun, ...) {
  bind_rows(dlply_(data, groups, fun, ...))
}

fct_explicit_na_ = function(x) {
  x = as.factor(x)
  if (anyNA(x) || anyNA(levels(x))) {
    na_name = "(Missing)"
    levels_x = levels(x)
    while (na_name %in% levels_x) {
      na_name = paste0(na_name, "+")
    }
    levels(x) = c(levels_x, na_name)
    x[is.na(x)] = na_name
  }
  x
}

dlply_ = function(data, groups, fun, ...) {
  # must make NAs explicit or they will be dropped by split()
  group_vars = lapply(data[, groups, drop = FALSE], fct_explicit_na_)

  if (length(group_vars) >= 1) {
    # group_is = a list where each element is a numeric vector of indices
    # corresponding to one group
    group_is = unname(split(seq_len(nrow(data)), group_vars, drop = TRUE, lex.order = TRUE))

    lapply(group_is, function(group_i) {
      # faster version of row_df = data[group_i, ]
      row_df = tibble::new_tibble(lapply(data, `[`, group_i), nrow = length(group_i))
      fun(row_df, ...)
    })
  } else {
    list(fun(data, ...))
  }
}

map_dbl_ = function(X, FUN, ...) {
  vapply(X, FUN, FUN.VALUE = numeric(1), ...)
}

map_lgl_ = function(X, FUN, ...) {
  vapply(X, FUN, FUN.VALUE = logical(1), ...)
}

map2_chr_ = function(X, Y, FUN) {
  as.character(mapply(FUN, X, Y, USE.NAMES = FALSE))
}

# map2_dfr_ = function(X, Y, FUN) {
#   bind_rows(mapply(FUN, X, Y, SIMPLIFY = FALSE, USE.NAMES = FALSE))
# }

fct_rev_ = function(x) {
  if (is.character(x)) {
    x = factor(x)
  } else if (!is.factor(x)) {
    stop0("`x` must be a factor (or character vector).")
  }
  factor(x, levels = rev(levels(x)), ordered = is.ordered(x))
}


# array manipulation ------------------------------------------------------

# flatten dimensions of an array
flatten_array = function(x) {
  # determine new dimension names in the form x,y,z
  # start with numeric names
  .dim = dim(x) %||% length(x)
  dimname_lists = lapply(.dim, seq_len)
  .dimnames = dimnames(x)
  if (!is.null(.dimnames)) {
    # where character names are provided, use those instead of the numeric names
    dimname_lists = lapply(seq_along(dimname_lists), function(i) .dimnames[[i]] %||% dimname_lists[[i]])
  }
  # if this has more than one dimension and the first dim is length 1 and is unnamed, drop it
  # basically: we don't want row vectors to have a bunch of "1,"s in front of their indices.
  if (length(.dim) > 1 && .dim[[1]] == 1 && length(.dimnames[[1]]) == 0) {
    dimname_lists = dimname_lists[-1]
  }

  # flatten array
  dim(x) = length(x)

  if (length(dimname_lists) == 1) {
    index_names = dimname_lists[[1]]
  } else {
    # expand out the dimname lists into the appropriate combinations and assemble into new names
    dimname_grid = expand.grid(dimname_lists, KEEP.OUT.ATTRS = FALSE)
    index_names = do.call(paste, c(list(sep = ","), dimname_grid))
    # make it a factor to preserve original order
    index_names = ordered(index_names, levels = index_names)
  }

  list(x = x, index_names = index_names)
}


# sequences ---------------------------------------------------------------

#' Create sequences of length n interleaved with its own reverse sequence.
#' e.g.
#' seq_interleaved(6) = c(1, 6, 2, 5, 3, 4)
#' seq_interleaved(5) = c(1, 5, 2, 4, 3)
#' @noRd
seq_interleaved = function(n) {
  if (n <= 2) {
    i = seq_len(n)
  } else {
    i = numeric(n)
    i[c(TRUE,FALSE)] = seq_len(ceiling(n/2))
    i[c(FALSE,TRUE)] = seq(n, ceiling(n/2) + 1)
  }

  i
}

#' a variant of seq_interleaved that proceeds outwards from the middle,
#' for use with side = "both" in dots geoms
#' @noRd
seq_interleaved_centered = function(n) {
  is_odd = n %% 2
  head = rev(seq_interleaved(floor(n/2))) * 2 - 1 + is_odd
  center = if (is_odd) 1
  tail = seq_interleaved(floor(n/2)) * 2 + is_odd
  c(head, center, tail)
}
