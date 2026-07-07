# lineage.R
# lg_lineage(): build a pipeline lineage graph from session operations.
# lg_plot():    render it inline (DiagrammeR) or write DOT to file.
#
# Zero new hard dependencies: DOT output works standalone.
# DiagrammeR is used for inline rendering if installed (listed in Suggests).
#
# Node types and colour scheme (IBM Plex palette):
#   source    -- initial tagged dataset    -- light blue  #e8effe
#   dataset   -- dataset after operation   -- white       #ffffff
#   derive    -- DERIVE operation          -- light yellow #fff8e1
#   join      -- JOIN operation            -- light green  #e8f5e9
#   filter    -- FILTER operation          -- light orange #fff3e0
#   exclusion -- excluded rows             -- light red    #ffebee


# --------------------------------------------------------------------------- #
#  lg_lineage                                                                  #
# --------------------------------------------------------------------------- #

#' Build a pipeline lineage graph from the active session
#'
#' Constructs a visual representation of the full pipeline : every tagged
#' dataset, every `lg_derive()`, `lg_join()`, and `lg_filter()` operation,
#' and every exclusion branch : as a list of nodes and edges with a
#' Graphviz DOT string.
#'
#' Render with [lg_plot()] for inline display in RStudio or a knitr document,
#' or write the DOT string to a file and render externally with Graphviz.
#'
#' @param rankdir Character. Layout direction: `"TB"` (top to bottom, default)
#'   or `"LR"` (left to right).
#'
#' @return An `lg_lineage` object (list) with components:
#' \describe{
#'   \item{`nodes`}{Named list of node metadata.}
#'   \item{`edges`}{Named list of edge metadata.}
#'   \item{`dot`}{Character string. Graphviz DOT representation.}
#'   \item{`rankdir`}{The layout direction used.}
#' }
#'
#' @examples
#' lg_start()
#' patients <- data.frame(
#'   USUBJID = c("P01", "P02", "P03", "P04", "P05"),
#'   eligible = c(TRUE, FALSE, TRUE, TRUE, FALSE),
#'   age = c(34L, 17L, 52L, 29L, 61L),
#'   stringsAsFactors = FALSE
#' )
#' pts <- lg_tag(patients, dataset_id = "PATIENTS")
#' pts <- lg_derive(pts,
#'   adult = age >= 18L,
#'   description = "adult flag from age"
#' )
#' lg_filter(pts, eligible & adult,
#'   reason = "Ineligible or under 18"
#' )
#'
#' lin <- lg_lineage()
#' print(lin)
#' lg_end()
#'
#' @seealso [lg_plot()], [lg_operations()], [lg_report()]
#' @export
lg_lineage <- function(rankdir = c("TB", "LR")) {
  .assert_active()
  rankdir <- match.arg(rankdir)

  nodes <- list()
  edges <- list()

  # Step 1: one source node per tagged dataset
  for (ds_id in names(.lg$datasets)) {
    ds <- .lg$datasets[[ds_id]]
    nid <- .node_id("SRC", ds_id)
    nodes[[nid]] <- .lineage_node(nid,
      label = sprintf("%s\nn = %d", ds_id, ds$n_rows),
      type  = "source"
    )
  }

  # Step 2: track the current tip node for each dataset
  tips <- stats::setNames(
    lapply(names(.lg$datasets), function(id) .node_id("SRC", id)),
    names(.lg$datasets)
  )

  # Step 3: replay operations in order, extending the graph
  for (op in .lg$operations) {
    ds_id <- op$dataset_id %||% "unknown"
    op_type <- op$op_type
    op_id <- op$op_id
    n_in <- op$rows_in %||% NA_integer_
    n_out <- op$rows_out %||% NA_integer_
    n_excl <- if (!is.na(n_in) && !is.na(n_out)) n_in - n_out else 0L
    desc <- .truncate_label(op$description %||% "")
    op_nid <- .node_id("OP", op_id)

    if (op_type == "FILTER") {
      nodes[[op_nid]] <- .lineage_node(op_nid,
        label = sprintf("FILTER\n%s\n\u2212%d rows", desc, n_excl),
        type  = "filter"
      )
      edges[[paste0(op_id, "_in")]] <- .lineage_edge(
        tips[[ds_id]], op_nid, sprintf("n=%d", n_in)
      )

      res_nid <- .node_id("DS", paste0(ds_id, "_", op_id))
      nodes[[res_nid]] <- .lineage_node(res_nid,
        label = sprintf("%s\nn = %d", ds_id, n_out),
        type  = "dataset"
      )
      edges[[paste0(op_id, "_out")]] <- .lineage_edge(op_nid, res_nid, "")

      if (!is.na(n_excl) && n_excl > 0L) {
        excl_nid <- .node_id("EXCL", op_id)
        nodes[[excl_nid]] <- .lineage_node(excl_nid,
          label = sprintf("excluded\nn = %d", n_excl),
          type  = "exclusion"
        )
        edges[[paste0(op_id, "_excl")]] <- .lineage_edge(op_nid, excl_nid, "")
      }

      tips[[ds_id]] <- res_nid
    } else if (grepl("^JOIN", op_type, ignore.case = TRUE)) {
      source_y <- op$source_y %||% "unknown"
      join_type <- tolower(gsub("^JOIN_", "", op_type))
      by_str <- op$by %||% "?"

      nodes[[op_nid]] <- .lineage_node(op_nid,
        label = sprintf("JOIN (%s)\nby: %s", join_type, by_str),
        type  = "join"
      )

      # Edge from x (left dataset)
      edges[[paste0(op_id, "_x")]] <- .lineage_edge(tips[[ds_id]], op_nid, "x")

      # Edge from y (right dataset) — use its current tip or source node
      y_tip <- tips[[source_y]]
      if (is.null(y_tip)) {
        y_src <- .node_id("SRC", source_y)
        if (is.null(nodes[[y_src]])) {
          ds_info <- .lg$datasets[[source_y]]
          nodes[[y_src]] <- .lineage_node(y_src,
            label = sprintf(
              "%s\nn = %s", source_y,
              if (!is.null(ds_info)) ds_info$n_rows else "?"
            ),
            type = "source"
          )
        }
        y_tip <- y_src
      }
      edges[[paste0(op_id, "_y")]] <- .lineage_edge(y_tip, op_nid, "y")

      res_nid <- .node_id("DS", paste0(ds_id, "_", op_id))
      nodes[[res_nid]] <- .lineage_node(res_nid,
        label = sprintf("%s\nn = %d", ds_id, n_out),
        type  = "dataset"
      )
      edges[[paste0(op_id, "_out")]] <- .lineage_edge(op_nid, res_nid, "")

      tips[[ds_id]] <- res_nid
    } else if (op_type == "DERIVE") {
      nodes[[op_nid]] <- .lineage_node(op_nid,
        label = sprintf("DERIVE\n%s", desc),
        type  = "derive"
      )
      edges[[paste0(op_id, "_in")]] <- .lineage_edge(tips[[ds_id]], op_nid, "")

      res_nid <- .node_id("DS", paste0(ds_id, "_", op_id))
      nodes[[res_nid]] <- .lineage_node(res_nid,
        label = sprintf("%s\nn = %d", ds_id, n_out),
        type  = "dataset"
      )
      edges[[paste0(op_id, "_out")]] <- .lineage_edge(op_nid, res_nid, "")

      tips[[ds_id]] <- res_nid
    }
  }

  dot <- .lineage_dot(nodes, edges, rankdir)

  structure(
    list(nodes = nodes, edges = edges, dot = dot, rankdir = rankdir),
    class = "lg_lineage"
  )
}


# --------------------------------------------------------------------------- #
#  lg_plot                                                                     #
# --------------------------------------------------------------------------- #

#' Render a lineage graph
#'
#' Renders the lineage graph returned by [lg_lineage()] as an interactive
#' inline widget (using `DiagrammeR` if installed), or writes the DOT source
#' to a file for rendering with Graphviz externally.
#'
#' @param lineage An `lg_lineage` object from [lg_lineage()].
#' @param output Character or `NULL`. File path for DOT output (e.g.
#'   `"pipeline.dot"`). When `NULL` (default), renders inline using
#'   `DiagrammeR::grViz()` if available, otherwise prints the DOT source
#'   to the console.
#'
#' @return The `lg_lineage` object, invisibly.
#'
#' @examples
#' \dontrun{
#' lg_start()
#' pts <- lg_tag(
#'   data.frame(
#'     USUBJID = c("P01", "P02"),
#'     eligible = c(TRUE, FALSE),
#'     stringsAsFactors = FALSE
#'   ),
#'   dataset_id = "PATIENTS"
#' )
#' lg_filter(pts, eligible, reason = "Not eligible")
#' lin <- lg_lineage()
#' lg_plot(lin)
#' lg_end()
#' }
#'
#' @seealso [lg_lineage()]
#' @export
lg_plot <- function(lineage, output = NULL) {
  if (!inherits(lineage, "lg_lineage")) {
    stop("`lineage` must be an `lg_lineage` object created by lg_lineage().")
  }

  if (!is.null(output)) {
    writeLines(lineage$dot, output)
    message(sprintf("lineager: lineage graph written to %s", output))
    return(invisible(lineage))
  }

  if (requireNamespace("DiagrammeR", quietly = TRUE)) {
    print(DiagrammeR::grViz(lineage$dot))
  } else {
    message(
      "lineager: install DiagrammeR for inline rendering:\n",
      "  install.packages(\"DiagrammeR\")\n\n",
      "DOT source (paste into https://dreampuf.github.io/GraphvizOnline/):\n"
    )
    cat(lineage$dot, "\n") # nolint: undesirable_function_linter
  }

  invisible(lineage)
}


# --------------------------------------------------------------------------- #
#  S3 methods                                                                  #
# --------------------------------------------------------------------------- #

#' @export
print.lg_lineage <- function(x, ...) {
  n_src <- sum(vapply(x$nodes, function(n) n$type == "source", logical(1L)))
  n_op <- sum(vapply(x$nodes, function(n) {
    n$type %in%
      c("derive", "join", "filter")
  }, logical(1L)))
  n_excl <- sum(vapply(x$nodes, function(n) n$type == "exclusion", logical(1L)))

  cat(sprintf(
    "<lg_lineage>  %d source dataset(s), %d operation(s), %d exclusion branch(es)\n",
    n_src, n_op, n_excl
  ))
  cat("Use lg_plot(lin) to render. DOT source:\n\n")
  cat(x$dot, "\n")
  invisible(x)
}


# --------------------------------------------------------------------------- #
#  Internal helpers                                                            #
# --------------------------------------------------------------------------- #

# Stable, valid DOT node identifier
.node_id <- function(prefix, suffix) {
  paste0(prefix, "_", gsub("[^a-zA-Z0-9_]", "_", suffix))
}

# Node metadata list
.lineage_node <- function(id, label, type) {
  list(id = id, label = label, type = type)
}

# Edge metadata list
.lineage_edge <- function(from, to, label = "") {
  list(from = from, to = to, label = label)
}

# Truncate node label description to max 35 characters
.truncate_label <- function(x) {
  x <- trimws(x)
  if (nchar(x) > 35L) paste0(substr(x, 1L, 32L), "...") else x
}

# Colour scheme (IBM Plex palette, matches lineager design system)
.lineage_colours <- list(
  source    = list(fill = "#e8effe", border = "#1a56db", font = "#0f1117"),
  dataset   = list(fill = "#ffffff", border = "#6b6f80", font = "#0f1117"),
  derive    = list(fill = "#fff8e1", border = "#f59e0b", font = "#0f1117"),
  join      = list(fill = "#e8f5e9", border = "#0e7a4f", font = "#0f1117"),
  filter    = list(fill = "#fff3e0", border = "#ea8c00", font = "#0f1117"),
  exclusion = list(fill = "#ffebee", border = "#dc2626", font = "#dc2626")
)

# Node shape per type
.lineage_shape <- function(type) {
  switch(type,
    source    = "box",
    dataset   = "box",
    derive    = "ellipse",
    join      = "diamond",
    filter    = "ellipse",
    exclusion = "plaintext",
    "box"
  )
}

# Build the complete DOT string from nodes and edges
.lineage_dot <- function(nodes, edges, rankdir) {
  lines <- sprintf(
    'digraph lineage {\n  rankdir = %s;\n  graph [fontname="Helvetica", splines=ortho, nodesep=0.4, ranksep=0.6];\n  node  [fontname="Helvetica", fontsize=10, margin="0.15,0.08"];\n  edge  [fontname="Helvetica", fontsize=9, color="#6b6f80"];\n',
    rankdir
  )

  for (nd in nodes) {
    cols <- .lineage_colours[[nd$type]]
    shape <- .lineage_shape(nd$type)
    label <- gsub("\n", "\\\\n", nd$label)
    label <- gsub('"', '\\\\"', label)

    if (nd$type == "exclusion") {
      lines <- c(lines, sprintf(
        '  %s [label="%s", shape=%s, fontcolor="%s", fontsize=9];',
        nd$id, label, shape, cols$font
      ))
    } else {
      lines <- c(lines, sprintf(
        '  %s [label="%s", shape=%s, style="filled,rounded", fillcolor="%s", color="%s", fontcolor="%s"];',
        nd$id, label, shape, cols$fill, cols$border, cols$font
      ))
    }
  }

  lines <- c(lines, "")

  for (ed in edges) {
    if (nzchar(ed$label)) {
      lines <- c(lines, sprintf(
        '  %s -> %s [label=" %s "];',
        ed$from, ed$to, ed$label
      ))
    } else {
      lines <- c(lines, sprintf("  %s -> %s;", ed$from, ed$to))
    }
  }

  lines <- c(lines, "}")
  paste(lines, collapse = "\n")
}
