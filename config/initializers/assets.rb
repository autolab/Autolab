# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
Rails.application.config.assets.precompile += %w( *.css )
Rails.application.config.assets.precompile += %w( gradesheet.css.scss )
Rails.application.config.assets.precompile += %w( mobile.scss )
Rails.application.config.assets.precompile += %w( annotations.scss )
Rails.application.config.assets.precompile += %w( groups.scss )
Rails.application.config.assets.precompile += %w( application.scss )
Rails.application.config.assets.precompile += %w( problems.css.scss )
Rails.application.config.assets.precompile += %w( assessments/* )
Rails.application.config.assets.precompile += %w( highlightjs-styles/* )
Rails.application.config.assets.precompile += %w( scaffold.scss )
Rails.application.config.assets.precompile += %w( beta.scss )
Rails.application.config.assets.precompile += %w( icons.css.scss )
Rails.application.config.assets.precompile += %w( scaffolds.scss )
Rails.application.config.assets.precompile += %w( instructor_gradebook.scss )
Rails.application.config.assets.precompile += %w( SlickGrid/* )
Rails.application.config.assets.precompile += %w( css/* )
Rails.application.config.assets.precompile += %w( student_gradebook.css.scss )
Rails.application.config.assets.precompile += %w( metricsgraphics_brushing.css )
Rails.application.config.assets.precompile += %w( style.css.scss )
Rails.application.config.assets.precompile += %w( metricsgraphics.scss )
Rails.application.config.assets.precompile += %w( users.css.scss )

Rails.application.config.assets.precompile += %w( *.js )
Rails.application.config.assets.precompile += %w( gradesheet.js.erb )
Rails.application.config.assets.precompile += %w( groups.coffee )
Rails.application.config.assets.precompile += %w( SlickGrid/* )