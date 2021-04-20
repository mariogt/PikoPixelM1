/*
    PPToolModifierTipsText.m

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

#import "PPToolModifierTipsText.h"

#import "PPTextAttributesDicts.h"


#define kToolModifierTipsStringsResourceName                    @"ToolModifierTipsStrings"

#define kModifiersDictKey_Root_TypeModifierTitlesDict           @"TypeModifierTitlesDict"
#define kModifiersDictKey_Root_ActionModifierTitlesDict         @"ActionModifierTitlesDict"
#define kModifiersDictKey_Root_ToolModifierDicts                @"ToolModifierDicts"

#define kModifiersDictKey_Titles_DescriptionPrefix              @"DescriptionTitlePrefix"
#define kModifiersDictKey_Titles_KeyNames                       @"KeyNamesTitle"
#define kModifiersDictKey_Titles_DefaultDescriptionSubtitle     @"DefaultDescriptionSubtitle"
#define kModifiersDictKey_Titles_DefaultKeyNamesSubtitle        @"DefaultKeyNamesSubtitle"

#define kModifiersDictKey_ToolModifiers_ToolName                @"ToolName"
#define kModifiersDictKey_ToolModifiers_TypeModifierDicts       @"TypeModifierDicts"
#define kModifiersDictKey_ToolModifiers_ActionModifierDicts     @"ActionModifierDicts"

#define kModifiersDictKey_Modifiers_CustomDescriptionSubtitle   @"CustomDescriptionSubtitle"
#define kModifiersDictKey_Modifiers_CustomKeyNamesSubtitle      @"CustomKeyNamesSubtitle"
#define kModifiersDictKey_Modifiers_ModifierStringDicts         @"ModifierStringDicts"

#define kModifiersDictKey_ModifierStrings_Description           @"Description"
#define kModifiersDictKey_ModifierStrings_KeyNames              @"KeyNames"


static bool gGlobalsHaveBeenSetUp = NO;
static NSAttributedString *gTypeModifierDescriptions[kNumPPToolTypes],
                            *gTypeModifierKeyNames[kNumPPToolTypes],
                            *gActionModifierDescriptions[kNumPPToolTypes],
                            *gActionModifierKeyNames[kNumPPToolTypes];

// The getModifierDescriptions:... private method (called by setupGlobals private method) is a
// patch target on GNUstep, so can't call setupGloblals from +initialize, because that would
// occur before the patch is installed; Instead, setupGlobals is called from within the three
// get*ModifierDecriptions:... public methods (whichever gets called first), using macro,
// macroValidateGlobals.

#define macroValidateGlobals    \
            ((gGlobalsHaveBeenSetUp || [PPToolModifierTipsText setupGlobals]) ? YES : NO)


@interface PPToolModifierTipsText (PrivateMethods)

+ (bool) setupGlobals;

+ (bool) getModifierDescriptions: (NSAttributedString **) returnedDescriptionsText
            andModifierKeyNames: (NSAttributedString **) returnedKeyNamesText
            forToolWithName: (NSString *) toolName
            usingModifierDicts: (NSArray *) modifierDicts
            andTitlesDict: (NSDictionary *) titlesDict;

@end

@implementation PPToolModifierTipsText

+ (bool) getMaxTextWidthForModifierDescriptions:
                                    (float *) returnedMaxTextWidth_ModifierDescriptions
            maxTextWidthForModifierKeyNames: (float *) returnedMaxTextWidth_ModifierKeyNames
            maxTextHeightForTypeModifiersText: (float *) returnedMaxTextHeight_TypeModifiers
            maxTextHeightForActionModifiersText: (float *) returnedMaxTextHeight_ActionModifiers
{
    static float maxTextWidth_ModifierDescriptions = 0.0f,
                    maxTextWidth_ModifierKeyNames = 0.0f,
                    maxTextHeight_TypeModifiers = 0.0f,
                    maxTextHeight_ActionModifiers = 0.0f;

    if (!macroValidateGlobals)
        goto ERROR;

    if (!returnedMaxTextWidth_ModifierDescriptions
        || !returnedMaxTextWidth_ModifierKeyNames
        || !returnedMaxTextHeight_TypeModifiers
        || !returnedMaxTextHeight_ActionModifiers)
    {
        goto ERROR;
    }

    if (maxTextWidth_ModifierDescriptions == 0.0f)
    {
        int i;
        NSSize textSize;

        for (i=0; i<kNumPPToolTypes; i++)
        {
            textSize = [gTypeModifierDescriptions[i] size];

            if (maxTextWidth_ModifierDescriptions < textSize.width)
            {
                maxTextWidth_ModifierDescriptions = textSize.width;
            }

            if (maxTextHeight_TypeModifiers < textSize.height)
            {
                maxTextHeight_TypeModifiers = textSize.height;
            }

            textSize = [gTypeModifierKeyNames[i] size];

            if (maxTextWidth_ModifierKeyNames < textSize.width)
            {
                maxTextWidth_ModifierKeyNames = textSize.width;
            }

            if (maxTextHeight_TypeModifiers < textSize.height)
            {
                maxTextHeight_TypeModifiers = textSize.height;
            }

            textSize = [gActionModifierDescriptions[i] size];

            if (maxTextWidth_ModifierDescriptions < textSize.width)
            {
                maxTextWidth_ModifierDescriptions = textSize.width;
            }

            if (maxTextHeight_ActionModifiers < textSize.height)
            {
                maxTextHeight_ActionModifiers = textSize.height;
            }

            textSize = [gActionModifierKeyNames[i] size];

            if (maxTextWidth_ModifierKeyNames < textSize.width)
            {
                maxTextWidth_ModifierKeyNames = textSize.width;
            }

            if (maxTextHeight_ActionModifiers < textSize.height)
            {
                maxTextHeight_ActionModifiers = textSize.height;
            }
        }
    }

    *returnedMaxTextWidth_ModifierDescriptions = maxTextWidth_ModifierDescriptions;
    *returnedMaxTextWidth_ModifierKeyNames = maxTextWidth_ModifierKeyNames;
    *returnedMaxTextHeight_TypeModifiers = maxTextHeight_TypeModifiers;
    *returnedMaxTextHeight_ActionModifiers = maxTextHeight_ActionModifiers;

    return YES;

ERROR:
    return NO;
}

+ (bool) getTypeModifierDescriptions: (NSAttributedString **) returnedTypeModifierDescriptions
            andTypeModifierKeyNames: (NSAttributedString **) returnedTypeModifierKeyNames
            forToolType: (PPToolType) toolType
{
    if (!macroValidateGlobals)
        goto ERROR;

    if (!PPToolType_IsValid(toolType)
        || !returnedTypeModifierDescriptions
        || !returnedTypeModifierKeyNames)
    {
        goto ERROR;
    }

    *returnedTypeModifierDescriptions = gTypeModifierDescriptions[(int) toolType];
    *returnedTypeModifierKeyNames = gTypeModifierKeyNames[(int) toolType];

    return YES;

ERROR:
    return NO;
}

+ (bool) getActionModifierDescriptions:
                                    (NSAttributedString **) returnedActionModifierDescriptions
            andActionModifierKeyNames: (NSAttributedString **) returnedActionModifierKeyNames
            forToolType: (PPToolType) toolType
{
    if (!macroValidateGlobals)
        goto ERROR;

    if (!PPToolType_IsValid(toolType)
        || !returnedActionModifierDescriptions
        || !returnedActionModifierKeyNames)
    {
        goto ERROR;
    }

    *returnedActionModifierDescriptions = gActionModifierDescriptions[(int) toolType];
    *returnedActionModifierKeyNames = gActionModifierKeyNames[(int) toolType];

    return YES;

ERROR:
    return NO;
}

#pragma mark Private methods

+ (bool) setupGlobals
{
    NSString *modifierTipsTextResourcePath, *toolName;
    NSDictionary *modifierTipsDict, *typeModifierTitlesDict, *actionModifierTitlesDict,
                    *toolModifiersDict;
    NSArray *toolModifierDicts, *typeModifierDicts, *actionModifierDicts;
    int i;
    NSAttributedString *typeModifierDescriptions, *typeModifierKeyNames,
                        *actionModifierDescriptions, *actionModifierKeyNames;
    static bool unableToSetupGlobals = NO;

    if (gGlobalsHaveBeenSetUp)
        return YES;

    if (unableToSetupGlobals)
        goto ERROR;

    modifierTipsTextResourcePath =
                [[NSBundle mainBundle] pathForResource: kToolModifierTipsStringsResourceName
                                        ofType: @"plist"];

    if (!modifierTipsTextResourcePath)
        goto ERROR;

    modifierTipsDict = [NSDictionary dictionaryWithContentsOfFile: modifierTipsTextResourcePath];

    if (!modifierTipsDict)
        goto ERROR;

    typeModifierTitlesDict =
        [modifierTipsDict objectForKey: kModifiersDictKey_Root_TypeModifierTitlesDict];

    actionModifierTitlesDict =
        [modifierTipsDict objectForKey: kModifiersDictKey_Root_ActionModifierTitlesDict];

    toolModifierDicts =
        [modifierTipsDict objectForKey: kModifiersDictKey_Root_ToolModifierDicts];

    if (!typeModifierTitlesDict
        || !actionModifierTitlesDict
        || ([toolModifierDicts count] != kNumPPToolTypes))
    {
        goto ERROR;
    }

    for (i=0; i<kNumPPToolTypes; i++)
    {
        toolModifiersDict = [toolModifierDicts objectAtIndex: i];

        toolName =
            [toolModifiersDict objectForKey: kModifiersDictKey_ToolModifiers_ToolName];

        typeModifierDicts =
            [toolModifiersDict objectForKey: kModifiersDictKey_ToolModifiers_TypeModifierDicts];

        actionModifierDicts =
            [toolModifiersDict objectForKey:
                                        kModifiersDictKey_ToolModifiers_ActionModifierDicts];

        if (![toolName length]
            || !typeModifierDicts
            || !actionModifierDicts)
        {
            goto ERROR;
        }

        if (![self getModifierDescriptions: &typeModifierDescriptions
                        andModifierKeyNames: &typeModifierKeyNames
                        forToolWithName: toolName
                        usingModifierDicts: typeModifierDicts
                        andTitlesDict: typeModifierTitlesDict]
            || ![self getModifierDescriptions: &actionModifierDescriptions
                        andModifierKeyNames: &actionModifierKeyNames
                        forToolWithName: toolName
                        usingModifierDicts: actionModifierDicts
                        andTitlesDict: actionModifierTitlesDict])
        {
            goto ERROR;
        }

        gTypeModifierDescriptions[i] = [typeModifierDescriptions retain];
        gTypeModifierKeyNames[i] = [typeModifierKeyNames retain];
        gActionModifierDescriptions[i] = [actionModifierDescriptions retain];
        gActionModifierKeyNames[i] = [actionModifierKeyNames retain];
    }

    gGlobalsHaveBeenSetUp = YES;

    return YES;

ERROR:
    unableToSetupGlobals = YES;

    return NO;
}

+ (bool) getModifierDescriptions: (NSAttributedString **) returnedDescriptionsText
            andModifierKeyNames: (NSAttributedString **) returnedKeyNamesText
            forToolWithName: (NSString *) toolName
            usingModifierDicts: (NSArray *) modifierDicts
            andTitlesDict: (NSDictionary *) titlesDict
{
    NSMutableAttributedString *descriptionsText, *keyNamesText;
    NSAttributedString *attrString;
    NSString *titlePrefix, *string;
    NSEnumerator *modifierDictsEnumerator, *modifierStringDictsEnumerator;
    NSDictionary *modifiersDict, *modifierStringsDict;
    NSArray *modifierStringDicts;

    if (!returnedDescriptionsText
        || !returnedKeyNamesText
        || !toolName
        || !modifierDicts
        || !titlesDict)
    {
        goto ERROR;
    }

    descriptionsText = [[[NSMutableAttributedString alloc] init] autorelease];
    keyNamesText = [[[NSMutableAttributedString alloc] init] autorelease];

    if (!descriptionsText || !keyNamesText)
    {
        goto ERROR;
    }

    // Titles

    titlePrefix = [titlesDict objectForKey: kModifiersDictKey_Titles_DescriptionPrefix];

    if (!titlePrefix)
        goto ERROR;

    string = [NSString stringWithFormat: @"%@%@", titlePrefix, toolName];

    if (!string)
        goto ERROR;

    attrString =
        [[[NSAttributedString alloc]
                                initWithString: string
                                attributes: PPTextAttributesDict_ToolModifierTips_Header()]
                        autorelease];

    if (!attrString)
        goto ERROR;

    [descriptionsText appendAttributedString: attrString];

    string = [titlesDict objectForKey: kModifiersDictKey_Titles_KeyNames];

    if (!string)
        goto ERROR;

    attrString =
        [[[NSAttributedString alloc]
                                initWithString: string
                                attributes: PPTextAttributesDict_ToolModifierTips_Header()]
                        autorelease];

    if (!attrString)
        goto ERROR;

    [keyNamesText appendAttributedString: attrString];

    // Modifier strings

    modifierDictsEnumerator = [modifierDicts objectEnumerator];

    while (modifiersDict = [modifierDictsEnumerator nextObject])
    {
        // Subtitles

        string =
            [modifiersDict objectForKey: kModifiersDictKey_Modifiers_CustomDescriptionSubtitle];

        if (!string)
        {
            string =
                [titlesDict objectForKey: kModifiersDictKey_Titles_DefaultDescriptionSubtitle];

            if (!string)
                goto ERROR;
        }

        string = [NSString stringWithFormat: @"\n%@", string];

        if (!string)
            goto ERROR;

        attrString =
            [[[NSAttributedString alloc]
                                    initWithString: string
                                    attributes:
                                            PPTextAttributesDict_ToolModifierTips_Subheader()]
                            autorelease];

        if (!attrString)
            goto ERROR;

        [descriptionsText appendAttributedString: attrString];

        string =
            [modifiersDict objectForKey: kModifiersDictKey_Modifiers_CustomKeyNamesSubtitle];

        if (!string)
        {
            string =
                [titlesDict objectForKey: kModifiersDictKey_Titles_DefaultKeyNamesSubtitle];

            if (!string)
                goto ERROR;
        }

        string = [NSString stringWithFormat: @"\n%@", string];

        if (!string)
            goto ERROR;

        attrString =
            [[[NSAttributedString alloc]
                                    initWithString: string
                                    attributes:
                                            PPTextAttributesDict_ToolModifierTips_Subheader()]
                            autorelease];

        if (!attrString)
            goto ERROR;

        [keyNamesText appendAttributedString: attrString];

        modifierStringDicts =
            [modifiersDict objectForKey: kModifiersDictKey_Modifiers_ModifierStringDicts];

        modifierStringDictsEnumerator = [modifierStringDicts objectEnumerator];

        while (modifierStringsDict = [modifierStringDictsEnumerator nextObject])
        {
            string =
                [modifierStringsDict objectForKey:
                                            kModifiersDictKey_ModifierStrings_Description];

            if (!string)
                goto ERROR;

            string = [NSString stringWithFormat: @"\n%@", string];

            if (!string)
                goto ERROR;

            attrString =
                [[[NSAttributedString alloc]
                                        initWithString: string
                                        attributes: PPTextAttributesDict_ToolModifierTips_Tips()]
                                autorelease];

            if (!attrString)
                goto ERROR;

            [descriptionsText appendAttributedString: attrString];

            string =
                [modifierStringsDict objectForKey: kModifiersDictKey_ModifierStrings_KeyNames];

            if (!string)
                goto ERROR;

            string = [NSString stringWithFormat: @"\n%@", string];

            if (!string)
                goto ERROR;

            attrString =
                [[[NSAttributedString alloc]
                                        initWithString: string
                                        attributes: PPTextAttributesDict_ToolModifierTips_Tips()]
                                autorelease];

            if (!attrString)
                goto ERROR;

            [keyNamesText appendAttributedString: attrString];
        }
    }

    *returnedDescriptionsText = descriptionsText;
    *returnedKeyNamesText = keyNamesText;

    return YES;

ERROR:
    return NO;
}

@end
