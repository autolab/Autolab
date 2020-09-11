# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path
# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
Rails.application.config.assets.precompile += %w( *.js )
Rails.application.config.assets.precompile += %w( animate.css )
Rails.application.config.assets.precompile += %w( gradesheet.css.scss )
Rails.application.config.assets.precompile += %w( mobile.css )
Rails.application.config.assets.precompile += %w( annotations.css )
Rails.application.config.assets.precompile += %w( groups.scss )
Rails.application.config.assets.precompile += %w( navbar.css )
Rails.application.config.assets.precompile += %w( application.scss )
Rails.application.config.assets.precompile += %w( highlight.css )
Rails.application.config.assets.precompile += %w( problems.css.scss )
Rails.application.config.assets.precompile += %w( assessments/* )
Rails.application.config.assets.precompile += %w( highlightjs-styles/* )
Rails.application.config.assets.precompile += %w( scaffold.css )
Rails.application.config.assets.precompile += %w( beta.css )
Rails.application.config.assets.precompile += %w( icons.css.scss )
Rails.application.config.assets.precompile += %w( scaffolds.scss )
Rails.application.config.assets.precompile += %w( chosen.min.css )
Rails.application.config.assets.precompile += %w( instructor_gradebook.css )
Rails.application.config.assets.precompile += %w( SlickGrid/* )
Rails.application.config.assets.precompile += %w( css/* )
Rails.application.config.assets.precompile += %w( jquery.dataTables.css )
Rails.application.config.assets.precompile += %w( student_gradebook.css.scss )
Rails.application.config.assets.precompile += %w( datatable.adapter.css )
Rails.application.config.assets.precompile += %w( metricsgraphics_brushing.css )
Rails.application.config.assets.precompile += %w( style.css.scss )
Rails.application.config.assets.precompile += %w( eventdrops.css )
Rails.application.config.assets.precompile += %w( metricsgraphics.css )
Rails.application.config.assets.precompile += %w( users.css.scss )
Rails.application.config.assets.precompile += %w( bootstrap-datetimepicker.css )

Rails.application.config.assets.precompile += %w( annotations.js )
Rails.application.config.assets.precompile += %w( chroma.min.js )
Rails.application.config.assets.precompile += %w( gradesheet.js.erb )
Rails.application.config.assets.precompile += %w( initialize_tooltips.js )
Rails.application.config.assets.precompile += %w( lodash_set_template_style.js )
Rails.application.config.assets.precompile += %w( pdf.worker.js )
Rails.application.config.assets.precompile += %w( table.js )
Rails.application.config.assets.precompile += %w( app-level.js )
Rails.application.config.assets.precompile += %w( confirm_discard_changes.js )
Rails.application.config.assets.precompile += %w( groups.coffee )
Rails.application.config.assets.precompile += %w( jquery.event.drag-2.2.js )
Rails.application.config.assets.precompile += %w( manage_submissions.js )
Rails.application.config.assets.precompile += %w( shortcut.js )
Rails.application.config.assets.precompile += %w( tango_status.js )
Rails.application.config.assets.precompile += %w( application.js )
Rails.application.config.assets.precompile += %w( d3.v3.min.js )
Rails.application.config.assets.precompile += %w( highlight.pack.js )
Rails.application.config.assets.precompile += %w( jquery.jeditable.js )
Rails.application.config.assets.precompile += %w( metricsgraphics_brushing.js )
Rails.application.config.assets.precompile += %w( SlickGrid/* )
Rails.application.config.assets.precompile += %w( users.js.coffee )
Rails.application.config.assets.precompile += %w( assessments_show.coffee )
Rails.application.config.assets.precompile += %w( eventdrops.js )
Rails.application.config.assets.precompile += %w( init_handin_datetimepickers.js )
Rails.application.config.assets.precompile += %w( jquery.simplemodal-1.4.4.js )
Rails.application.config.assets.precompile += %w( metricsgraphics.min.js )
Rails.application.config.assets.precompile += %w( sorttable.js )
Rails.application.config.assets.precompile += %w( validateIntegrity.js )
Rails.application.config.assets.precompile += %w( chosen.jquery.min.js )
Rails.application.config.assets.precompile += %w( gradebook.js )
Rails.application.config.assets.precompile += %w( initialize_datetimepickers.js )
Rails.application.config.assets.precompile += %w( jquery.stickytableheaders.js )
Rails.application.config.assets.precompile += %w( pdf.js )
Rails.application.config.assets.precompile += %w( table_floating_header.js )
Rails.application.config.assets.precompile += %w( bootstrap-datetimepicker.js )
