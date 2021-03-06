
function modCreate_SoundEventsUi() : CModSoundEventsUi {
    // do nothing besides creating and returning of mod class!
    return new CModSoundEventsUi in thePlayer;
}

// ----------------------------------------------------------------------------
class CModSoundEventsUiList extends CModUiFilteredList {

    public function initList() {
		var data: C2dArray;
        var i: int;
		var col0, cat1, cat2, cat3, id, caption : String;

        data = LoadCSV("dlc/dlcsoundeventsui/data/sound_events_list.csv");

        items.Clear();

        // csv: CAT1;CAT2;CAT3;id;caption
        for (i = 0; i < data.GetNumRows(); i += 1) {
            col0 = data.GetValueAt(0, i);
            cat1 = data.GetValueAt(1, i);
            cat2 = data.GetValueAt(2, i);
            cat3 = data.GetValueAt(3, i);
            id = data.GetValueAt(4, i);
            caption = data.GetValueAt(5, i);
			
			//LogChannel('CModSoundEventsUiList', "cat1 [" + cat1 + "], cat2 [" + cat2 + "], cat3 [" + cat3 + "], id [" + id + "], caption [" + caption + "]");
			
            items.PushBack(SModUiCategorizedListItem(
                id,
                caption,
                cat1,
                cat2,
                cat3
            ));
        }
    }

}
// ----------------------------------------------------------------------------
// callback for generic ui list which will call example mod back
class CModSoundEventsUiListCallback extends IModUiEditableListCallback {
    public var callback: CModSoundEventsUi;

    public function OnOpened() { callback.OnUpdateView(); }

    public function OnInputEnd(inputString: String) { callback.OnInputEnd(inputString); }

    public function OnInputCancel() { callback.OnInputCancel(); }

    public function OnClosed() { delete listMenuRef; }

    public function OnSelected(optionName: String) { callback.OnSelected(optionName); }
}
// ----------------------------------------------------------------------------
class CModSoundEventsUi extends CMod {
    default modName = 'SoundEventsUi';
    default modAuthor = "nikich340";
    default modUrl = "http://www.nexusmods.com/witcher3/mods/5070/";
    default modVersion = '1.0';

    default logLevel = MLOG_DEBUG;

    protected var view: CModSoundEventsUiListCallback;
    protected var listProvider: CModSoundEventsUiList;
	
	public var lastEventName : String; default lastEventName = "null";
	public var lastBankName : String;
	protected var isMusicMuted : bool;	default isMusicMuted  = false;
	protected var isSoundsMuted : bool; default isSoundsMuted = false;
	
	// ------------------------------------------------------------------------
	public function notify(msg : string) {
		theGame.GetGuiManager().ShowNotification(msg);
	}

    // ------------------------------------------------------------------------
    public function init() {
        // prepare view callback wiring and set labels
        view = new CModSoundEventsUiListCallback in this;
        view.callback = this;
        view.title = "Sound events UI";   // title currently unused (missing swf element for now)
        view.statsLabel = "Sound events";  // used for showing number of seen elements

        // load example data into list provider
        listProvider = new CModSoundEventsUiList in this;
        listProvider.initList();

        // simple dummy hotkey binding for menu (reusing vanilla actions just for this example)
        // bind some other keys to test properly...
        // for a sane usage a new inputcontext should be started when menu is
        // opened and restored after it is closed
        // selection works either with mouse or space/enter
		
        //theInput.RegisterListener(this, 'OnOpenMenu', 'SteelSword');
        theInput.RegisterListener(this, 'OnFilter', 'SoundEventsUi_SetFilter');
        theInput.RegisterListener(this, 'OnResetFilter', 'SoundEventsUi_ResetFilter');
        theInput.RegisterListener(this, 'OnReset', 'SoundEventsUi_Reset');
        theInput.RegisterListener(this, 'OnQuit', 'SoundEventsUi_Quit');
        theInput.RegisterListener(this, 'OnCategoryUp', 'SoundEventsUi_ListCategoryUp');
        theInput.RegisterListener(this, 'OnLogEvent', 'SoundEventsUi_LogEvent');
		theInput.RegisterListener(this, 'OnHelpMePrettyPlease', 'SoundEventsUi_ShowHelp');
		theInput.RegisterListener(this, 'OnStopMusic', 'SoundEventsUi_StopMusic');
		theInput.RegisterListener(this, 'OnMuteMusic', 'SoundEventsUi_SwitchMuteMusic');
		theInput.RegisterListener(this, 'OnMuteSounds', 'SoundEventsUi_SwitchMuteSounds');
		theInput.RegisterListener(this, 'OnGameplayMusic', 'SoundEventsUi_GameplayMusic');
		
		LogChannel('MOD_SoundEventsUi', "------- START SoundEvents UI -------");
    }

	private function saveGameplaySettings() {
		/*if (modSoundEventsUtil) {
			modSoundEventsUtil.freezeTime();
			modSoundEventsUtil.deactivateHud();
		}*/

        // stop envui breakage if enemies attack
        thePlayer.SetTemporaryAttitudeGroup('q104_avallach_friendly_to_all', AGP_Default);
		thePlayer.SetImmortalityMode( AIM_Immortal, AIC_Combat );
		thePlayer.SetImmortalityMode( AIM_Immortal, AIC_Default );
		thePlayer.SetImmortalityMode( AIM_Immortal, AIC_Fistfight );
		thePlayer.SetImmortalityMode( AIM_Immortal, AIC_IsAttackableByPlayer );
    }
    // ------------------------------------------------------------------------
    private function restoreGameplaySettings() {
        thePlayer.ResetTemporaryAttitudeGroup(AGP_Default);
		thePlayer.SetImmortalityMode( AIM_None, AIC_Combat );
		thePlayer.SetImmortalityMode( AIM_None, AIC_Default );
		thePlayer.SetImmortalityMode( AIM_None, AIC_Fistfight );
		thePlayer.SetImmortalityMode( AIM_None, AIC_IsAttackableByPlayer );
    }
	// ------------------------------------------------------------------------
    public function openMenu() {
		saveGameplaySettings();
		FactsAdd('SoundEventsUi_active', 1);
		theSound.EnableMusicDebug(true);
		theInput.StoreContext('MOD_SoundEventsUi');
        theGame.RequestMenu('ListView', view);
		GetWitcherPlayer().DisplayHudMessage(GetLocStringByKeyExt("SoundEventsUI_Started"));
    }
	
	public function closeMenu() {
		FactsAdd('SoundEventsUi_active', -1);
		theSound.EnableMusicDebug(false);
		
		theInput.UnregisterListener(this, 'SoundEventsUi_SetFilter');
        theInput.UnregisterListener(this, 'SoundEventsUi_ResetFilter');
        theInput.UnregisterListener(this, 'SoundEventsUi_Reset');
        theInput.UnregisterListener(this, 'SoundEventsUi_Quit');
        theInput.UnregisterListener(this, 'SoundEventsUi_ListCategoryUp');
		theInput.UnregisterListener(this, 'SoundEventsUi_ShowHelp');
		theInput.UnregisterListener(this, 'SoundEventsUi_LogEvent');
		theInput.UnregisterListener(this, 'SoundEventsUi_StopMusic');
		theInput.UnregisterListener(this, 'SoundEventsUi_SwitchMuteMusic');
		theInput.UnregisterListener(this, 'SoundEventsUi_SwitchMuteSounds');
		theInput.UnregisterListener(this, 'SoundEventsUi_GameplayMusic');
		theInput.RestoreContext('MOD_SoundEventsUi', true);
		restoreGameplaySettings();
		if (isMusicMuted || isSoundsMuted) {
			notify("WARNING! Sounds and/or music are still muted!");
		}
		GetWitcherPlayer().DisplayHudMessage(GetLocStringByKeyExt("SoundEventsUI_Closed"));
	}
	
	public function playSoundEvent(listItemId : String) {
		var eventName, bankName, areaName : String;
		
		bankName = StrBeforeFirst(listItemId, ":");
		eventName = StrAfterFirst(listItemId, ":");
		//NTR_notify("Play id [" + listItemId + "] ev [" + eventName + "] bnk [" + bankName + "]");
		
		if ( !theSound.SoundIsBankLoaded(bankName) ) {
			theSound.SoundLoadBank(bankName, true);
		}
		lastBankName = bankName;
		lastEventName = eventName;
		if ( StrContains(listItemId, "music") ) {
			// check if it is music event - then we should stop current and launch special play_music_<area> event //
			switch (bankName) {
				case "music_toussaint.bnk":
					theSound.InitializeAreaMusic( (EAreaName)AN_Dlc_Bob );
					break;
				case "music_skellige.bnk":
					theSound.InitializeAreaMusic( AN_Skellige_ArdSkellig );
					break;
				case "music_wyzima_castle.bnk":
					theSound.InitializeAreaMusic( AN_Wyzima );
					break;
				case "music_misty_island.bnk":
					theSound.InitializeAreaMusic( AN_Island_of_Myst );
					break;
				case "music_prologue.bnk":
					theSound.InitializeAreaMusic( AN_Prologue_Village_Winter );
					break;
				case "music_kaer_morhen.bnk":
					theSound.InitializeAreaMusic( AN_Kaer_Morhen );
					break;
				case "music_spiral.bnk":
					theSound.InitializeAreaMusic( AN_Spiral );
					break;
				case "music_nomansgrad.bnk":
					theSound.InitializeAreaMusic( AN_NMLandNovigrad );
					break;
				case "music_main_menu_credits.bnk":
					theSound.SoundEvent("stop_music");
					theSound.SoundEvent("play_music_main_menu");
					break;
				default: // only stop_music event //
					theSound.InitializeAreaMusic( AN_Undefined );
					break;
			}
			theSound.SoundEvent(eventName);
		} else {
			theSound.SoundEvent(eventName);
			thePlayer.SoundEvent(eventName);
		}
	}
	// ------------------------------------------------------------------------
    event OnHelpMePrettyPlease(action: SInputAction) {
        var helpPopup: CModUiHotkeyHelp;
        var titleKey: String;
        var introText: String;
        var hotkeyList: array<SModUiHotkeyHelp>;

        if (IsPressed(action)) {
            helpPopup = new CModUiHotkeyHelp in this;
            titleKey = "SoundEventsUI_tHelpHotkey";
            introText += "<p align=\"left\">" + GetLocStringByKeyExt("SoundEventsUI_GeneralHelp") + "</p>";

            hotkeyList.PushBack(HotkeyHelp_from('SoundEventsUi_ShowHelp'));
            hotkeyList.PushBack(HotkeyHelp_from('SoundEventsUi_ListCategoryUp'));
			hotkeyList.PushBack(HotkeyHelp_from('SoundEventsUi_LogEvent'));
            hotkeyList.PushBack(HotkeyHelp_from('SoundEventsUi_GameplayMusic'));
            hotkeyList.PushBack(HotkeyHelp_from('SoundEventsUi_SwitchMuteMusic'));
            hotkeyList.PushBack(HotkeyHelp_from('SoundEventsUi_SwitchMuteSounds'));
			hotkeyList.PushBack(HotkeyHelp_from('SoundEventsUi_StopMusic'));
            hotkeyList.PushBack(HotkeyHelp_from('SoundEventsUi_Reset'));
            hotkeyList.PushBack(HotkeyHelp_from('SoundEventsUi_SetFilter'));
            hotkeyList.PushBack(HotkeyHelp_from('SoundEventsUi_ResetFilter'));
            hotkeyList.PushBack(HotkeyHelp_from('SoundEventsUi_Quit'));

            helpPopup.open(titleKey, introText, hotkeyList);
        }
    }
	// -----------------------------------------------------------------------
	event OnGameplayMusic(action: SInputAction) {
        if (IsPressed(action)) {
			theSound.InitializeAreaMusic( theGame.GetCommonMapManager().GetCurrentArea() );
			notify("Switch to gameplay music");
        }
    }
	// -----------------------------------------------------------------------
	event OnQuit(action: SInputAction) {
        if (IsPressed(action)) {
			closeMenu();
        }
    }
	// -----------------------------------------------------------------------
	event OnMuteMusic(action: SInputAction) {
        if (IsPressed(action)) {
			if ( !theSound.SoundIsBankLoaded("vo_definitions.bnk") ) {
				theSound.SoundLoadBank("vo_definitions.bnk", true);
			}
			if (!isMusicMuted) {
				theSound.SoundEvent("mute_music");
				notify("Mute music");
			} else {
				theSound.SoundEvent("unmute_music");
				notify("Unmute music");
			}
			isMusicMuted = !isMusicMuted;
        }
    }
	// -----------------------------------------------------------------------
	event OnMuteSounds(action: SInputAction) {
        if (IsPressed(action)) {
			if ( !theSound.SoundIsBankLoaded("vo_definitions.bnk") ) {
				theSound.SoundLoadBank("vo_definitions.bnk", true);
			}
			if (!isSoundsMuted) {
				theSound.SoundEvent("mute_sounds");
				notify("Mute all sounds");
			} else {
				theSound.SoundEvent("unmute_sounds");
				notify("Unmute all sounds");
			}
			isSoundsMuted = !isSoundsMuted;
        }
    }
    // ------------------------------------------------------------------------
    // called by user action to open menu
    event OnOpenMenu(action: SInputAction) {
        // open only on action start
        if (IsPressed(action)) {
            openMenu();
        }
    }
	
	event OnReset(action: SInputAction) {
        // open only on action start
        if (IsPressed(action)) {
            listProvider.resetWildcardFilter();
			view.listMenuRef.resetEditField();
			
			listProvider.clearLowestSelectedCategory();
			listProvider.clearLowestSelectedCategory();
			listProvider.clearLowestSelectedCategory();

			updateView();
        }
    }
	
	event OnStopMusic(action: SInputAction) {
        // open only on action start
        if (IsPressed(action)) {
			theSound.SoundEvent("stop_music");
			notify("Stop current music");
        }
    }
	
	event OnLogEvent(action: SInputAction) {
        // open only on action start
        if (IsPressed(action)) {
			if (lastEventName != "null") {
				LogChannel('MOD_SoundEventsUi', "SOUND EVENT: [" + lastEventName + "], BANK NAME: [" + lastBankName + "]");
				notify("Event & bank names were logged");
			} else {
				notify("Sound event was not selected");
			}
        }
    }

    // called by user action to start filter input
    event OnFilter(action: SInputAction) {
        if (!view.listMenuRef.isEditActive() && IsPressed(action)) {

            view.listMenuRef.startInputMode(
                //GetLocStringByKeyExt("MyModFilter"),
                "Filter List",
                listProvider.getWildcardFilter());
        }
    }
	
    // called by user action to reset currently set filter
    event OnResetFilter() {
        listProvider.resetWildcardFilter();
        view.listMenuRef.resetEditField();

        updateView();
    }

    // called by user action to go one opened category up
    event OnCategoryUp(action: SInputAction) {
        if (IsPressed(action)) {
            listProvider.clearLowestSelectedCategory();
            updateView();
        }
    }
    // ------------------------------------------------------------------------
    // -- called by listview
    // called if user exits edit mode in list
    event OnInputCancel() {
        notify("edit canceled");

        view.listMenuRef.resetEditField();
        updateView();
    }

    // called when user ends edit (return pressed)
    event OnInputEnd(inputString: String) {
        if (inputString == "") {
            OnResetFilter();
        } else {
            // Note: filter field is not removed to indicate the current filter
            listProvider.setWildcardFilter(inputString);
            updateView();
        }
    }

    // called when list item was selected
    event OnSelected(listItemId: String) {
        // listprovider opens a category if a category was selected otherwise
        // returns true (meaning a "real" item was selected)
        if (listProvider.setSelection(listItemId, true)) {
            playSoundEvent(listItemId);			
        }
        updateView();
    }

    // called when list menu opens first time
    event OnUpdateView() {
        var wildcard: String;
        // Note: if search filter is active show the wildcard to indicate the
        // current filter
        wildcard = listProvider.getWildcardFilter();
        if (wildcard != "") {
            view.listMenuRef.setInputFieldData(
                //GetLocStringByKeyExt("MyModFilter"),
                "Filter List",
                wildcard);
        }
        updateView();
    }
    // ------------------------------------------------------------------------
    protected function updateView() {
        // set updated list data and render in listview
        view.listMenuRef.setListData(
            listProvider.getFilteredList(),
            listProvider.getMatchingItemCount(),
            // number of items without filtering
            listProvider.getTotalCount());

        view.listMenuRef.updateView();
    }
}
// ----------------------------------------------------------------------------

exec function soundui(optional force : bool) {
	var isActive : int;
	var mod : CModSoundEventsUi;
	isActive = FactsQuerySum("SoundEventsUi_active");
	if (!isActive || force) {
		mod = modCreate_SoundEventsUi();
		mod.init();
		mod.openMenu();
	} else {
		theGame.GetGuiManager().ShowNotification( GetLocStringByKeyExt("SoundEventsUI_AlreadyOpened") );
	}
}