# WF main page UI
wfUI <- function(id){
    ns <- NS(id)
    desc <-
    '
    Workflow management guides you step by step to prepare a data analysis workflow,
    and enbles you to run some simple workflows directly from this app. The
    workflow will be prepared in [systemPipeR (SPR){blk}](https://systempipe.org/sp)
    format and it can be used in other similar compatible workflow environments.

    *****

    #### Expand to watch the tutorial
    <div style="text-align: center;">
        <video style="width: 100%; aspect-ratio: 16 / 9"  controls>
            <source src="https://user-images.githubusercontent.com/35240440/199857935-64267b1a-fbb2-4a9c-a460-bafcf2f6e95a.mp4" type="video/mp4">
            Video cannot be loaded or your browser does not support the video tag.
        </video>
    </div>

    `WARNING: This module will allow users to access some server files and run
    random R code in the workflow running session (step 5). It is recommended to use
    this module locally. If there is public access, consider to provide this serivce
    in an isolated place, like inside a container/ sandbox.`

    #### Quick start
    To run a workflow, you need to create a workflow environment and prepare
    some files. Follow this order:

    1. Generate a workflow environment (**required**).
    2. Prepare a targets (metadata) file (**required**).
    3. Prepare a workflow (Rmd) file (**required**).
    4. Check if CWL files are correct (optional).
    5. Run the workflow.

    To quickly run the example, click **Gen Worklfow** in (1) and **Add to task**
    on (2) and (3). Once workflow set up is done, you can run workflow at (5).

    When the workflow running session starts, you will be locked into a specified
    new page. This will set your working directory into the workflow folder (no
    longer the SPS app folder). When you quit, the working directory will be set
    back to SPS app folder.

    **Note**: Quiting the workflow session while jobs are still running may cause
    the workflow fail. Some SPR workflow configs require you to have the workflow
    folder as the current working directory.

    You can read more details about workflow management at
    [our website{blk}](https://systempipe.org/sp/)
    '
    tagList(
        tags$head(
            tags$script(src = "sps/js/split1.6.0.js"),
            tags$script(type="module", src = "sps/js/sps_wf.js"),
            tags$link(rel="stylesheet", href = "sps/css/sps_wf.css"),
            spsDepend("css-loader")
        ),
        tabTitle("Data analysis workflows"),
        renderDesc(ns("desc"), desc),
        spsHr(),
        br(),
        h3("Track workflow preparation status", class = "text-center text-info"),
        spsTimeline(
            ns("wf_status"),
            up_labels = c("1", "2", "3", "4 Optional", "5"),
            down_labels = c("Gen WF", "Targets", "WF file", "CWL files", "Ready to run"),
            icons = list(
                icon("play"),
                icon("table"),
                icon("list-ol"),
                icon("file-code"),
                icon("check")
            ),
            completes = c(FALSE, FALSE, FALSE, TRUE, FALSE)
        ),
        # actionButton(ns("set"), "set"),
        bsplus::bs_accordion(id = ns("wf_panel")) %>%
            bsplus::bs_set_opts(panel_type = "default") %>%
            bsplus::bs_append("1. Create a workflow environment", wf_setupUI(ns("wf_setup")), panel_type = "success") %>%
            bsplus::bs_append("2. Prepare the targets file", wf_targetUI(ns("wf_targets"))) %>%
            bsplus::bs_append("3. Prepare the workflow object", wf_wfUI(ns("wf"))) %>%
            bsplus::bs_set_opts(panel_type = "success") %>%
            bsplus::bs_append("4. Edit CWL files", wf_cwlUI(ns("wf_cwl"))) %>%
            bsplus::bs_set_opts(panel_type = "default") %>%
            bsplus::bs_append("5. Run workflow", wf_runUI(ns("wf_run"))),
        hexPanel(ns("poweredby"), "THIS TAB IS POWERED BY:",
                 hex_imgs = c(
                     "img/sps_small.png",
                     "https://raw.githubusercontent.com/systemPipeR/systemPipeR.github.io/main/static/images/systemPipeR.png",
                     "img/cwl.png"
                 ),
                 hex_titles = c("SystemPipeShiny", "SystemPipeR", "Common Workflow Language"),
                 hex_links = c(
                     "https://github.com/systemPipeR/systemPipeShiny/",
                     "https://systempipe.org/",
                     "https://www.commonwl.org/"
                 ),
                 ys = c("-20", "-10", "-20"),
                 xs = c("-10", "-10", "35")
        )
    )
}
## server
wfServer <- function(id, shared){
    module <- function(input, output, session){
        ns <- session$ns
        if(length(checkNameSpace("systemPipeR", quietly = TRUE)) != 0) return({
            spswarn("Install systemPipeR version >= 1.27.10")
            shinyjs::runjs('$("#shiny-tab-wf").children().remove();$("#shiny-tab-wf").append($("<h4>Insatall systemPipeR &gt;= 1.27.10</h4>"))')
        })
        if(packageVersion("systemPipeR") < "1.27.11") return({
            spswarn("Upgrade systemPipeR version >= 1.27.10")
            shinyjs::runjs('$("#shiny-tab-wf").children().remove();$("#shiny-tab-wf").append($("<h4>Upgrade systemPipeR version &gt;= 1.27.10</h4>"))')
        })
        wf_targetServer("wf_targets", shared)
        wf_setupServer("wf_setup", shared)
        wf_wfServer("wf", shared)
        wf_cwlServer("wf_cwl", shared)
        wf_runServer("wf_run", shared)
        # observeEvent(input$set, {
        #     pushbar::pushbar_open(id = "core_top-wf_push")
        # })
        # init wf env
        observeEvent(1, {
            shared$wf$env_option = NULL
            shared$wf$env_path = NULL
            shared$wf$targets_path = NULL
            shared$wf$wf_path = NULL
            shared$wf$flags = list(
                env_ready = 0,
                targets_ready = 0,
                wf_ready = 0
            )
            shared$wf$all_ready = FALSE
            shared$wf$wf_session_open = FALSE
            shared$wf$sal = NULL
            shared$wf$spr_loaded = if("systemPipeR" %in% (.packages())) TRUE else FALSE
            shared$wf$rs <- NULL
            shared$wf$rs_info$log_name <- NULL
            shared$wf$rs_info$log_path <- NULL
            shared$wf$rs_info$created <- FALSE
            shared$wf$rs_info$pid <- NULL
            shared$wf$rs_info$rs_dir <- NULL
        }, once = TRUE)
        # status change
        observeEvent(shared$wf$flags, {
            updateSpsTimeline(session, "wf_status", 1, as.logical(shared$wf$flags$env_ready))
            shinyjs::toggleCssClass("wf-wf_panel-0", "panel-success", asis = TRUE, shared$wf$flags$env_ready)
            updateSpsTimeline(session, "wf_status", 2,  as.logical(shared$wf$flags$targets_ready))
            shinyjs::toggleCssClass("wf-wf_panel-1", "panel-success", asis = TRUE, shared$wf$flags$targets_ready)
            updateSpsTimeline(session, "wf_status", 3,  as.logical(shared$wf$flags$wf_ready))
            shinyjs::toggleCssClass("wf-wf_panel-2", "panel-success", asis = TRUE,  as.logical(shared$wf$flags$wf_ready))

        }, ignoreInit = TRUE)
        # hide step 2,3,5 if 1 is not ready
        observeEvent(shared$wf$flags$env_ready, {
            shinyjs::toggleElement(
                "wf_targets_displayed", asis = TRUE,
                anim = TRUE, animType = "fade",
                condition = shared$wf$flags$env_ready
            )
            shinyjs::toggleElement(
                "wf_targets_disable", asis = TRUE,
                anim = TRUE, animType = "fade",
                condition = !shared$wf$flags$env_ready
            )
        })
        # show 3 if 2 is ready
        observeEvent(shared$wf$flags$targets_ready, {
            shinyjs::toggleElement(
                "wf_wf_displayed", asis = TRUE,
                anim = TRUE, animType = "fade",
                # condition = shared$wf$flags$targets_ready
                condition = shared$wf$flags$targets_ready
            )
            shinyjs::toggleElement(
                "wf_wf_disable", asis = TRUE,
                anim = TRUE, animType = "fade",
                # condition = !shared$wf$flags$targets_ready
                condition = !shared$wf$flags$targets_ready
            )
        })
        observeEvent(shared$wf$flags, {
            req(all(shared$wf$flags %>% unlist() %>% as.logical()))
            shared$wf$all_ready <- TRUE
        }, ignoreInit = TRUE)

        observeEvent(shared$wf$all_ready, {
            updateSpsTimeline(session, "wf_status", 5, shared$wf$all_ready)
            shinyjs::toggleCssClass("wf-wf_panel-4", "panel-success", asis = TRUE, shared$wf$all_ready)
            shinyjs::toggleElement(
                "wf_run_displayed", asis = TRUE,
                anim = TRUE, animType = "fade",
                condition = shared$wf$all_ready
            )
            shinyjs::toggleElement(
                "wf_run_disable", asis = TRUE,
                anim = TRUE, animType = "fade",
                condition = !shared$wf$all_ready
            )
        }, ignoreInit = TRUE)
        # session end call back
        session$onEnded(function(){
            "" ## nothing for now
        })
    }
    moduleServer(id, module)
}





















