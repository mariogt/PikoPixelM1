/*
    PPHotkeyType.h

    Copyright 2013-2018 Josh Freeman
    http://www.twilightedge.com

    This file is part of PikoPixel for Mac OS X and GNUstep.
    PikoPixel is a graphical application for drawing & editing pixel-art images.

    PikoPixel is free software: you can redistribute it and/or modify it under
    the terms of the GNU Affero General Public License as published by the
    Free Software Foundation, either version 3 of the License, or (at your
    option) any later version approved for PikoPixel by its copyright holder (or
    an authorized proxy).

    PikoPixel is distributed in the hope that it will be useful, but WITHOUT ANY
    WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
    FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
    details.

    You should have received a copy of the GNU Affero General Public License
    along with this program. If not, see <http://www.gnu.org/licenses/>.
*/


typedef enum
{
    // Must match array returned by PPHotkeys.m private function, SetupHotkeyDictKeysArray()

    kPPHotkeyType_Tool_Pencil,
    kPPHotkeyType_Tool_Eraser,
    kPPHotkeyType_Tool_Fill,
    kPPHotkeyType_Tool_Line,
    kPPHotkeyType_Tool_Rect,
    kPPHotkeyType_Tool_Oval,
    kPPHotkeyType_Tool_FreehandSelect,
    kPPHotkeyType_Tool_RectSelect,
    kPPHotkeyType_Tool_MagicWand,
    kPPHotkeyType_Tool_ColorSampler,
    kPPHotkeyType_Tool_Move,
    kPPHotkeyType_Tool_Magnifier,

    kPPHotkeyType_PopupPanel_Tools,
    kPPHotkeyType_PopupPanel_ColorPicker,
    kPPHotkeyType_PopupPanel_LayerControls,
    kPPHotkeyType_PopupPanel_Navigator,

    kPPHotkeyType_PopupPanel_ToolsAlternate,
    kPPHotkeyType_PopupPanel_ColorPickerAlternate,
    kPPHotkeyType_PopupPanel_LayerControlsAlternate,
    kPPHotkeyType_PopupPanel_NavigatorAlternate,

    kPPHotkeyType_SwitchCanvasViewMode,
    kPPHotkeyType_SwitchLayerOperationTarget,
    kPPHotkeyType_ToggleActivePanels,
    kPPHotkeyType_ToggleColorPickerPanel,
    kPPHotkeyType_ZoomIn,
    kPPHotkeyType_ZoomOut,
    kPPHotkeyType_ZoomToFit,
    kPPHotkeyType_BlinkDocumentLayers,

    kNumPPHotkeyTypes

} PPHotkeyType;


static inline bool PPHotkeyType_IsValid(PPHotkeyType hotkeyType)
{
    return (((unsigned) hotkeyType) < kNumPPHotkeyTypes) ? YES : NO;
}
