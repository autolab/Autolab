/** 
 *  editor.js
 *  
 *  This contains a namespacing object for the Autolab text editor.
 *  The bulk of the logic for that implementation lives here.
 * 
 *  The editor makes use of the Ace (formerly Skywriter, formerly Bespin)
 *  editor. It along with jQuery need to be included before this.
 */

var AutolabEditor = {

	// Variable to hold the editor object so other things
	// can access it later.
	editor: null,

	/*
	 * Initialization function. Call this before you do anyting else.
	 *
	 * @param codeElementId This is the id of the element you
	 * want to turn into an editor.
	 */
	init: function(codeElementId) {
		this.editor = ace.edit(codeElementId);
	},

	/*
	 * Setup the editing modes available for the editor.
	 * 
	 * @param modeArray an array of mode names (which must be the same as
	 * those used by Ace) that are supported. This is here because the 
	 * Ruby and Javascript code share this list and it sits in a Ruby
	 * helper which means it has to be dumped into an erb.
	 *
	 * @param selectId The id of the select box that controls which editing
	 * mode is being used.
	 */
	setupModes: function(modeArray, selectId) {
		var selector = '#' + selectId;
		var modes = {};
		var setMode;

		// Builds the mode objects, whose urls and ace paths have a
		// consistent format.
		$.each(modeArray, function(index, value) {
			if (value !== 'text') {
				modes[value] = {
					loaded: false,
					url: '/javascripts/ace/mode-' + value + '.js',
					requirePath: 'ace/mode/' + value,
					mode: null
				};
			}  else {
				var TextMode = require('ace/mode/text').Mode;
				modes[value] = {
					loaded: true,
					mode: new TextMode()
				};
			}
		});
		
		// Lazy loading of the mode files. If a mode it requested
		// for the first time, it's script is pulled from the server.
		// executed. Yes, this is kosher.
		setMode = function(name) {
			var mode = modes[name];
			if (!mode) {
				return;
			}

			if (mode.loaded) {
				AutolabEditor.editor.getSession().setMode(mode.mode);
				return;
			}

			$.getScript(mode.url, function() {
				var modeClass = require(mode.requirePath).Mode;
				mode.mode = new modeClass();
				mode.loaded = true;
				AutolabEditor.editor.getSession().setMode(mode.mode);
			});
		};

		// Actually set the value and setup the event handler.
		setMode($(selector).val());
		$(selector).change(function() {
			setMode(this.value);
		});
	},

	/* 
	 * Setup the keybindings available. Currently these are
	 * the standard Ace bindings, Vim and Emacs.
	 * 
	 * @param selectId The id of the select box used to choose the
	 * binding.
	 */
	setupBindings: function(selectId) {
		var selector = '#' + selectId;

		// Might as well be explicit about it. Ruby code doesn't need to
		// know about this.
		var keybindings = {
			emacs: {
				capName: 'Emacs',
				loaded: false,
				url: '/javascripts/ace/keybinding-emacs.js',
				requirePath: 'ace/keyboard/keybinding/emacs',
				binding: null
			},
			vim: {
				capName: 'Vim',
				loaded: false,
				url: '/javascripts/ace/keybinding-vim.js',
				requirePath: 'ace/keyboard/keybinding/vim',
				binding: null
			}, 
			standard: {
				loaded: true,
				binding: null
			}
		};

		// Once again, we do some lazy loading.
		var setBinding = function(name) {
			var keybinding = keybindings[name];
			if (!keybinding) {
				return;
			}

			if (keybinding.loaded) {
				AutolabEditor.editor.setKeyboardHandler(keybinding.binding);
				return;
			}

			$.getScript(keybinding.url, function() {
				keybinding.binding = require(keybinding.requirePath)[keybinding.capName];
				keybinding.loaded = true;
				AutolabEditor.editor.setKeyboardHandler(keybinding.binding);
			});
		};

		//Actually set the value and setup the event handler.
		setBinding($(selector).val());
		$(selector).change(function() {
			setBinding(this.value);
		});
	},

	/*
	 * Setup the word wrapping options. It's either
	 * off or it wraps at the screen edge. Arbitrary 
	 * column values are possible, but seemed pointless.
	 * 
	 * @param checkboxId The id of the checkbox used to enable
	 * and disabled word wrap.
	 */
	setupWrapping: function(checkboxId) {
		var selector = '#' + checkboxId;
		var modifyWrap = function(soft) {
			var session = AutolabEditor.editor.getSession();
			var renderer = AutolabEditor.editor.renderer;

			if (soft) {
				session.setUseWrapMode(true);
				session.setWrapLimitRange(null, null);
				renderer.setPrintMarginColumn(80);
			} else {
				session.setUseWrapMode(false);
				renderer.setPrintMarginColumn(80);
			}
		};

		modifyWrap($(selector).prop('checked'));
		$(selector).change(function() {
			modifyWrap(this.checked);
		});
	},

	/*
	 * Setup the tab type options. It's either soft or hard.
	 * 
	 * @param checkboxId The id of the checkbox used to enable
	 * or disable soft tabs.
	 */
	setupTabs: function(checkboxId) {
		var selector = '#' + checkboxId;
		AutolabEditor.editor.getSession().setUseSoftTabs($(selector).prop('checked'));
		$(selector).change(function() {
			AutolabEditor.editor.getSession().setUseSoftTabs(this.checked);
		});
	},

	/*
	 * Setup the show invisibles option. It's either on or off.
	 * 
	 * @param checkboxId The id of the checkbox used to enable
	 * or disabled showing invisibles.
	 */
	setupInvisibles: function(checkboxId) {
		var selector = '#' + checkboxId;
		AutolabEditor.editor.setShowInvisibles($(selector).prop('checked'));
		$(selector).change(function() {
			AutolabEditor.editor.setShowInvisibles(this.checked);
		});
	},

	/*
	 * Setup the theme. You can have any theme you want
	 * as long as it's Eclipse.
	 */
	setupTheme: function() {
		AutolabEditor.editor.setTheme('ace/theme/eclipse');
	},

	/*
	 * Setup the saving framework.
	 *
	 * @param sendLink The url to which the text in the editor get's
	 * sent on a save event. It is POSTed and in the toSave parameter.
	 *
	 * @param saveFormId The id of the form that, on submission
	 * triggers a save event.
	 */
	setupSaving: function(sendLink, saveFormId) {
		var selector = '#' + saveFormId;
		var textChanged = false;
		var save = function() {
			$.post(sendLink, { toSave: AutolabEditor.editor.getSession().getValue() }, function() {
				textChanged = false;
			});
		};

		// Add a shortcut.
		AutolabEditor.editor.commands.addCommand({
			name: 'Save',
			bindKey: {
				win: 'Ctrl-S',
				mac: 'Command-S',
				sender: 'editor'
			},
			exec: save
		});

		// Save on submission.
		$(selector).submit(function() {
			save();
			return false;
		});

		AutolabEditor.editor.getSession().on('change', function() {
			textChanged = true;
		});

		// Try to stop people from leaving with unsaved changes.
		$(window).bind('beforeunload', function() {
			if (textChanged) {
				return "The document has unsaved changes.";
			} else {
				return null;
			}
		});
	}
};
