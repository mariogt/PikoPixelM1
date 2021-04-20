/*
    NSObject_PPUtilities_MethodSwizzling.m

    Copyright 2013-2018,2020 Josh Freeman
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

#import "NSObject_PPUtilities.h"

#import <objc/runtime.h>


@implementation NSObject (PPUtilities_MethodSwizzling_OBJC_API_2)

+ (bool) ppSwizzleClassMethodWithSelector: (SEL) selector1
            forClassMethodWithSelector: (SEL) selector2
{
    Method method1, method2;
    const char *typeEncoding1, *typeEncoding2;
    IMP implementation1, implementation2;
    Class metaClass;

    if (!selector1 || !selector2 || sel_isEqual(selector1, selector2))
    {
        goto ERROR;
    }

    method1 = class_getClassMethod(self, selector1);
    method2 = class_getClassMethod(self, selector2);

    if (!method1 || !method2)
    {
        goto ERROR;
    }

    typeEncoding1 = method_getTypeEncoding(method1);
    typeEncoding2 = method_getTypeEncoding(method2);

    if (!typeEncoding1 || !typeEncoding2 || strcmp(typeEncoding1, typeEncoding2))
    {
        goto ERROR;
    }

    implementation1 = method_getImplementation(method1);
    implementation2 = method_getImplementation(method2);

    if (!implementation1 || !implementation2)
    {
        goto ERROR;
    }

    metaClass = object_getClass(self);

    // set method1's imp to implementation2

    if (class_addMethod(metaClass, selector1, implementation2, typeEncoding1))
    {
        method1 = class_getClassMethod(self, selector1);

        if (!method1)
            goto ERROR;
    }
    else
    {
        class_replaceMethod(metaClass, selector1, implementation2, typeEncoding1);
    }

    // set method2's imp to implementation1

    if (class_addMethod(metaClass, selector2, implementation1, typeEncoding2))
    {
        method2 = class_getClassMethod(self, selector2);

        if (!method2)
            goto ERROR;
    }
    else
    {
        class_replaceMethod(metaClass, selector2, implementation1, typeEncoding2);
    }

    // verify imps are swapped

    if ((method_getImplementation(method1) != implementation2)
        || (method_getImplementation(method2) != implementation1))
    {
        goto ERROR;
    }

    return YES;

ERROR:
    NSLog(@"WARNING: Unable to swizzle %@ class methods: %@ & %@",
            [self className],
            (selector1) ? NSStringFromSelector(selector1) : @"<NULL>",
            (selector2) ? NSStringFromSelector(selector2) : @"<NULL>");

    return NO;
}

+ (bool) ppSwizzleInstanceMethodWithSelector: (SEL) selector1
            forInstanceMethodWithSelector: (SEL) selector2
{
    Method method1, method2;
    const char *typeEncoding1, *typeEncoding2;
    IMP implementation1, implementation2;

    if (!selector1 || !selector2 || sel_isEqual(selector1, selector2))
    {
        goto ERROR;
    }

    method1 = class_getInstanceMethod(self, selector1);
    method2 = class_getInstanceMethod(self, selector2);

    if (!method1 || !method2)
    {
        goto ERROR;
    }

    typeEncoding1 = method_getTypeEncoding(method1);
    typeEncoding2 = method_getTypeEncoding(method2);

    if (!typeEncoding1 || !typeEncoding2 || strcmp(typeEncoding1, typeEncoding2))
    {
        goto ERROR;
    }

    implementation1 = method_getImplementation(method1);
    implementation2 = method_getImplementation(method2);

    if (!implementation1 || !implementation2)
    {
        goto ERROR;
    }

    // set method1's imp to implementation2

    if (class_addMethod(self, selector1, implementation2, typeEncoding1))
    {
        method1 = class_getInstanceMethod(self, selector1);

        if (!method1)
            goto ERROR;
    }
    else
    {
        class_replaceMethod(self, selector1, implementation2, typeEncoding1);
    }

    // set method2's imp to implementation1

    if (class_addMethod(self, selector2, implementation1, typeEncoding2))
    {
        method2 = class_getInstanceMethod(self, selector2);

        if (!method2)
            goto ERROR;
    }
    else
    {
        class_replaceMethod(self, selector2, implementation1, typeEncoding2);
    }

    // verify imps are swapped

    if ((method_getImplementation(method1) != implementation2)
        || (method_getImplementation(method2) != implementation1))
    {
        goto ERROR;
    }

    return YES;

ERROR:
    NSLog(@"WARNING: Unable to swizzle %@ instance methods: %@ & %@",
            [self className],
            (selector1) ? NSStringFromSelector(selector1) : @"<NULL>",
            (selector2) ? NSStringFromSelector(selector2) : @"<NULL>");

    return NO;
}

@end
