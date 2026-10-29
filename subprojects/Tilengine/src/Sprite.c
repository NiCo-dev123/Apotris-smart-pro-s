/*
 * Tilengine - The 2D retro graphics engine with raster effects
 * Copyright (C) 2015-2019 Marc Palacios Domenech <mailto:megamarc@hotmail.com>
 * All rights reserved
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 * */

#include "Sprite.h"
#include "Blitters.h"
#include "Debug.h"
#include "Engine.h"
#include "Math2D.h"
#include "Palette.h"
#include "Spriteset.h"
#include "Tables.h"
#include "Tilengine.h"
#include <math.h>
#include <string.h>

#ifdef _MSC_VER
#define inline __inline
#endif

static void SelectSpriteBlitter(Sprite* sprite);
static void UpdateSpriteTransform(Sprite* sprite);
static void UpdateSpriteBounds(Sprite* sprite);

/*!
 * \deprecated use \ref TLN_SetSpriteSet and \ref TLN_EnableSpriteFlag
 * \brief
 * Configures a sprite, setting spriteset and flags at once
 *
 * \param nsprite
 * Id of the sprite [0, num_sprites - 1]
 *
 * \param spriteset
 * Reference of the spriteset containing the graphics to set
 *
 * \param flags
 * Can be 0 or a combination of FLAG_FLIPX and FLAG_FLIPY
 *
 * \remarks
 * This function also assigns the palette of the spriteset
 * \see
 * TLN_SetSpritePicture()
 */
bool TLN_ConfigSprite(int nsprite, TLN_Spriteset spriteset, uint32_t flags) {
    return TLN_SetSpriteSet(nsprite, spriteset) &&
           TLN_SetSpriteFlags(nsprite, flags);
}

/*!
 * \brief
 * Assigns the spriteset and its palette to a given sprite
 *
 * \param nsprite
 * Id of the sprite [0, num_sprites - 1]
 *
 * \param spriteset
 * Reference of the spriteset containing the graphics to set
 *
 * \remarks
 * This function also assigns the palette of the spriteset and resets pivot to
 * top left corner (default)
 *
 * \see
 * TLN_SetSpritePicture()
 */
bool TLN_SetSpriteSet(int nsprite, TLN_Spriteset spriteset) {
    Sprite* sprite;
    bool enabled;
    if (nsprite >= engine->numsprites) {
        TLN_SetLastError(TLN_ERR_IDX_SPRITE);
        return false;
    }
    if (!CheckBaseObject(spriteset, OT_SPRITESET))
        return false;

    sprite = &engine->sprites[nsprite];
    sprite->spriteset = spriteset;
    sprite->pitch = sprite->spriteset->bitmap->pitch;
    enabled = sprite->ok;
    if (spriteset->palette)
        sprite->palette = spriteset->palette;
    sprite->ok = sprite->spriteset && sprite->palette;
    if (sprite->ok) {
        sprite->num = nsprite;
        sprite->ptx = sprite->pty = 0.0f;
        /* initialize transform fields */
        sprite->has_transform = false;
        sprite->affine.angle = 0.0f;
        sprite->affine.dx = 0.0f;
        sprite->affine.dy = 0.0f;
        sprite->affine.sx = 1.0f;
        sprite->affine.sy = 1.0f;
        Point2DSet(&sprite->pivot, sprite->ptx,
                   sprite->pty); /* use existing pivot values */
        Matrix3SetIdentity(&sprite->transform);
        sprite->ok = TLN_SetSpritePicture(nsprite, 0);
    }

    /* sprite enabled: add to the end */
    if (enabled == false && sprite->ok == true)
        ListAppendNode(&engine->list_sprites, nsprite);

    return sprite->ok;
}

/*!
 * \deprecated Use \ref TLN_EnableSpriteFlag to enable or disable individual
 * flags \brief Sets flags for a given sprite
 *
 * \param nsprite
 * Id of the sprite [0, num_sprites - 1]
 *
 * \param flags
 * Can be 0 or a combination of TLN_TileFlags
 */
bool TLN_SetSpriteFlags(int nsprite, uint32_t flags) {
    if (nsprite >= engine->numsprites) {
        TLN_SetLastError(TLN_ERR_IDX_SPRITE);
        return false;
    }

    engine->sprites[nsprite].flags = flags;
    TLN_SetLastError(TLN_ERR_OK);
    return true;
}

/*!
 * \brief Enables or disables specified flag for a sprite
 * \param nsprite of the sprite [0, num_sprites - 1]
 * \param flag flag (or combination of flags) to modfy
 * \param enable true for enable, false for disable
 */
bool TLN_EnableSpriteFlag(int nsprite, uint32_t flag, bool enable) {
    if (nsprite >= engine->numsprites) {
        TLN_SetLastError(TLN_ERR_IDX_SPRITE);
        return false;
    }

    if (enable)
        engine->sprites[nsprite].flags |= flag;
    else
        engine->sprites[nsprite].flags &= ~flag;

    TLN_SetLastError(TLN_ERR_OK);
    return true;
}

/*!
 * \brief
 * Sets the sprite position in screen space
 *
 * \param nsprite
 * Id of the sprite [0, num_sprites - 1]
 *
 * \param x
 * Horizontal position of pivot (0 = left margin)
 *
 * \param y
 * Vertical position of pivot (0 = top margin)
 *
 * \remarks
 * Call this function inside a raster callback to so some vertical distortion
 * effects (fake scaling) or sprite multiplexing (reusing a single sprite at
 * different screen heights). This technique was used by some 8 bit games, with
 * very few hardware sprites, to draw much more sprites in the screen, as long
 * as they don't overlap vertically
 *
 * \sa TLN_SetSpritePivot
 */
bool TLN_SetSpritePosition(int nsprite, int x, int y) {
    Sprite* sprite;
    if (nsprite >= engine->numsprites) {
        TLN_SetLastError(TLN_ERR_IDX_SPRITE);
        return false;
    }

    sprite = &engine->sprites[nsprite];
    sprite->x = x;
    sprite->y = y;
    UpdateSprite(sprite);

    TLN_SetLastError(TLN_ERR_OK);
    return true;
}

/*!
 * \brief
 * Sets the actual graphic to the sprite
 *
 * \param nsprite
 * Id of the sprite [0, num_sprites - 1]
 *
 * \param entry
 * Index of the actual picture inside the srpteset to assign (0 <= entry <
 * num_spriteset_graphics)
 *
 * \see
 * TLN_SetSpriteSet()
 */
bool TLN_SetSpritePicture(int nsprite, int entry) {
    Sprite* sprite;
    if (nsprite >= engine->numsprites) {
        TLN_SetLastError(TLN_ERR_IDX_SPRITE);
        return false;
    }

    sprite = &engine->sprites[nsprite];
    if (!CheckBaseObject(sprite->spriteset, OT_SPRITESET))
        return false;

    sprite->index = entry;
    sprite->info = &sprite->spriteset->data[entry];
    sprite->pixels = sprite->spriteset->bitmap->data + sprite->info->offset;
    sprite->pitch = sprite->spriteset->mapping_1d ? sprite->info->w : sprite->spriteset->bitmap->pitch;
    UpdateSprite(sprite);
    debugmsg("SetSpritePicture %d -> %d\n", nsprite, entry);

    TLN_SetLastError(TLN_ERR_OK);
    return true;
}

/*!
 * \brief
 * Assigns a palette to a sprite
 *
 * \param nsprite
 * Id of the sprite [0, num_sprites - 1]
 *
 * \param palette
 * Reference of the palete to assign
 */
bool TLN_SetSpritePalette(int nsprite, TLN_Palette palette) {
    Sprite* sprite;
    if (nsprite >= engine->numsprites) {
        TLN_SetLastError(TLN_ERR_IDX_SPRITE);
        return false;
    }
    if (!CheckBaseObject(palette, OT_PALETTE))
        return false;

    sprite = &engine->sprites[nsprite];
    sprite->palette = palette;
    sprite->ok = sprite->spriteset && sprite->palette;

    TLN_SetLastError(TLN_ERR_OK);
    return true;
}

/*!
 * \brief
 * Gets the palette assigned to a given sprite
 *
 * \param nsprite
 * Id of the sprite to query (0 <= id < max_sprites)
 *
 * \returns
 * Reference to the sprite palette
 *
 * \see
 * TLN_SetSpritePalette(), TLN_SetSpriteSet()
 */
TLN_Palette TLN_GetSpritePalette(int nsprite) {
    if (nsprite >= engine->numsprites) {
        TLN_SetLastError(TLN_ERR_IDX_SPRITE);
        return NULL;
    }

    TLN_SetLastError(TLN_ERR_OK);
    return engine->sprites[nsprite].palette;
}

/*
 * \brief returns sprite's horizontal position
 * \param nsprite Sprite index to query
 * \returns x position
 * \see TLN_SetSpritePosition()
 */
int TLN_GetSpriteX(int nsprite) {
    if (nsprite >= engine->numsprites) {
        TLN_SetLastError(TLN_ERR_IDX_SPRITE);
        return 0;
    }

    TLN_SetLastError(TLN_ERR_OK);
    return engine->sprites[nsprite].x;
}

/*
 * \brief returns sprite's vertical position
 * \param nsprite Sprite index to query
 * \returns y position
 * \see TLN_SetSpritePosition()
 */
int TLN_GetSpriteY(int nsprite) {
    if (nsprite >= engine->numsprites) {
        TLN_SetLastError(TLN_ERR_IDX_SPRITE);
        return 0;
    }

    TLN_SetLastError(TLN_ERR_OK);
    return engine->sprites[nsprite].y;
}

/*!
 * \brief
 * Sets the blending mode (transparency effect)
 *
 * \param nsprite
 * Id of the sprite [0, num_sprites - 1]
 *
 * \param mode
 * Member of the TLN_Blend enumeration
 *
 * \param factor
 * Deprecated as of 1.12, left for backwards compatibility but doesn't have
 * effect.
 *
 * \see
 * Blending
 */
bool TLN_SetSpriteBlendMode(int nsprite, TLN_Blend mode, uint8_t factor) {
    Sprite* sprite;
    if (nsprite >= engine->numsprites) {
        TLN_SetLastError(TLN_ERR_IDX_SPRITE);
        return false;
    }

    sprite = &engine->sprites[nsprite];
    sprite->blend = SelectBlendTable(mode);
    SelectSpriteBlitter(sprite);

    TLN_SetLastError(TLN_ERR_OK);
    return true;
}

/*!
 * \brief
 * Sets the scaling factor of the sprite
 *
 * \param nsprite
 * Id of the sprite [0, num_sprites - 1]
 *
 * \param sx
 * Horizontal scale factor
 *
 * \param sy
 * Vertical scale factor
 *
 * By default the scaling factor of a given sprite is 1.0f, 1.0f, which means
 * no scaling. Use values below 1.0 to downscale (shrink) and above 1.0 to
 * upscale (enlarge). Call TLN_ResetScaling() to disable scaling
 *
 * \remarks
 * The rendering of a sprite with scaling enabled requires somewhat more CPU
 * power than a regular sprite.
 *
 * \see
 * TLN_ResetSpriteScaling()
 */
bool TLN_SetSpriteScaling(int nsprite, float sx, float sy) {
    Sprite* sprite;
    if (nsprite >= engine->numsprites) {
        TLN_SetLastError(TLN_ERR_IDX_SPRITE);
        return false;
    }

    sprite = &engine->sprites[nsprite];
    sprite->sx = sx;
    sprite->sy = sy;
    sprite->mode = MODE_SCALING;
    sprite->draw = GetSpriteDraw(sprite->mode);
    UpdateSprite(sprite);
    SelectSpriteBlitter(sprite);
    return true;
}

/*!
 * \brief
 * Disables scaling for a given sprite
 *
 * \param nsprite
 * Id of the sprite [0, num_sprites - 1]
 *
 * \see
 * TLN_SetSpriteScaling()
 */
bool TLN_ResetSpriteScaling(int nsprite) {
    Sprite* sprite;
    if (nsprite >= engine->numsprites) {
        TLN_SetLastError(TLN_ERR_IDX_SPRITE);
        return false;
    }

    sprite = &engine->sprites[nsprite];
    sprite->sx = sprite->sy = 1.0f;
    sprite->mode = MODE_NORMAL;
    sprite->draw = GetSpriteDraw(sprite->mode);
    UpdateSprite(sprite);

    TLN_SetLastError(TLN_ERR_OK);
    SelectSpriteBlitter(sprite);
    return true;
}

/*!
 * \brief
 * Sets sprite rotation angle
 *
 * \param nsprite
 * Id of the sprite [0, num_sprites - 1]
 *
 * \param angle
 * Rotation angle in degrees (0-360)
 *
 * \returns
 * true if success or false if error
 *
 * \see
 * TLN_ResetSpriteRotation()
 */
bool TLN_SetSpriteRotation(int nsprite, float angle) {
    Sprite* sprite;

    if (nsprite >= engine->numsprites) {
        TLN_SetLastError(TLN_ERR_IDX_SPRITE);
        return false;
    }

    sprite = &engine->sprites[nsprite];
    if (!sprite->ok) {
        TLN_SetLastError(TLN_ERR_REF_SPRITESET);
        return false;
    }

    sprite->affine.angle = fmod(angle, 360.0f);
    sprite->affine.dx = 0;
    sprite->affine.dy = 0;

    // Preserve existing scaling instead of resetting to 1.0f
    sprite->affine.sx = sprite->sx;
    sprite->affine.sy = sprite->sy;
    sprite->has_transform = true;

    UpdateSpriteTransform(sprite);
    UpdateSpriteBounds(sprite);

    TLN_SetLastError(TLN_ERR_OK);
    return true;
}

/*!
 * \brief
 * Resets sprite rotation
 *
 * \param nsprite
 * Id of the sprite [0, num_sprites - 1]
 *
 * \returns
 * true if success or false if error
 *
 * \see
 * TLN_SetSpriteRotation()
 */
bool TLN_ResetSpriteRotation(int nsprite) {
    Sprite* sprite;

    if (nsprite >= engine->numsprites) {
        TLN_SetLastError(TLN_ERR_IDX_SPRITE);
        return false;
    }

    sprite = &engine->sprites[nsprite];
    if (!sprite->ok) {
        TLN_SetLastError(TLN_ERR_REF_SPRITESET);
        return false;
    }

    sprite->has_transform = false;
    UpdateSpriteTransform(sprite);
    UpdateSpriteBounds(sprite);

    TLN_SetLastError(TLN_ERR_OK);
    return true;
}

/*!
 * \brief
 * Sets sprite transformation parameters
 *
 * \param nsprite
 * Id of the sprite [0, num_sprites - 1]
 *
 * \param angle
 * Rotation angle in degrees
 *
 * \param dx
 * Horizontal translation
 *
 * \param dy
 * Vertical translation
 *
 * \param sx
 * Horizontal scaling factor
 *
 * \param sy
 * Vertical scaling factor
 *
 * \returns
 * true if success or false if error
 *
 * \see
 * TLN_SetSpriteAffineTransform()
 */
bool TLN_SetSpriteTransform(int nsprite, float angle, float dx, float dy,
                            float sx, float sy) {
    Sprite* sprite;

    if (nsprite >= engine->numsprites) {
        TLN_SetLastError(TLN_ERR_IDX_SPRITE);
        return false;
    }

    sprite = &engine->sprites[nsprite];
    if (!sprite->ok) {
        TLN_SetLastError(TLN_ERR_REF_SPRITESET);
        return false;
    }

    sprite->affine.angle = fmod(angle, 360.0f);
    sprite->affine.dx = dx;
    sprite->affine.dy = dy;
    sprite->affine.sx = sx;
    sprite->affine.sy = sy;
    sprite->has_transform = true;

    UpdateSpriteTransform(sprite);
    UpdateSpriteBounds(sprite);

    TLN_SetLastError(TLN_ERR_OK);
    return true;
}

/*!
 * \brief
 * Sets sprite affine transformation parameters
 *
 * \param nsprite
 * Id of the sprite [0, num_sprites - 1]
 *
 * \param affine
 * Pointer to affine transformation structure
 *
 * \returns
 * true if success or false if error
 *
 * \see
 * TLN_SetSpriteTransform()
 */
bool TLN_SetSpriteAffineTransform(int nsprite, TLN_Affine* affine) {
    Sprite* sprite;

    if (nsprite >= engine->numsprites || !affine) {
        TLN_SetLastError(TLN_ERR_IDX_SPRITE);
        return false;
    }

    sprite = &engine->sprites[nsprite];
    if (!sprite->ok) {
        TLN_SetLastError(TLN_ERR_REF_SPRITESET);
        return false;
    }

    sprite->affine = *affine;
    sprite->affine.angle = fmod(affine->angle, 360.0f);
    sprite->has_transform = true;

    UpdateSpriteTransform(sprite);
    UpdateSpriteBounds(sprite);

    TLN_SetLastError(TLN_ERR_OK);
    return true;
}

/*!
 * \brief
 * Returns the index of the assigned picture from the spriteset
 *
 * \param nsprite
 * Id of the sprite [0, num_sprites - 1]
 *
 * \see
 * TLN_SetSpritePicture()
 */
int TLN_GetSpritePicture(int nsprite) {
    if (nsprite >= engine->numsprites) {
        TLN_SetLastError(TLN_ERR_IDX_SPRITE);
        return 0;
    }

    TLN_SetLastError(TLN_ERR_OK);
    return engine->sprites[nsprite].index;
}

/*!
 * \brief
 * Finds an available (unused) sprite
 *
 * \returns
 * Index of the first unused sprite (starting from 0) or -1 if none found
 */
int TLN_GetAvailableSprite(void) {
    int c;

    TLN_SetLastError(TLN_ERR_OK);
    for (c = 0; c < engine->numsprites; c++) {
        if (!engine->sprites[c].ok)
            return c;
    }
    return -1;
}

/*!
 * \brief
 * Enable sprite collision checking at pixel level
 *
 * \param nsprite
 * Id of the sprite [0, num_sprites - 1]
 *
 * \param enable
 * Set true to enable o false to disable (default value)
 *
 * \remarks
 * Only sprites that have collision enabled are checked between them,
 * so to detect a collision between two sprites, both of them must
 * have collision detection enabled. Processing collision detection
 * sprites take more a bit more CPU time compared to non-colliding sprites, so
 * by default it is disabled on all sprites.
 *
 * \see
 * TLN_GetSpriteCollision()
 */
bool TLN_EnableSpriteCollision(int nsprite, bool enable) {
    if (nsprite >= engine->numsprites) {
        TLN_SetLastError(TLN_ERR_IDX_SPRITE);
        return false;
    }

    engine->sprites[nsprite].do_collision = enable;
    return true;
}

/*!
 * \brief
 * Gets the collision status of a given sprite
 *
 * \param nsprite
 * Id of the sprite [0, num_sprites - 1]
 *
 * \returns
 * Tue if this sprite is involved in a collision with another sprite
 *
 * \remarks
 * Collision detection must be enabled for the sprite to get checked
 *
 * \see
 * TLN_EnableSpriteCollision()
 */
bool TLN_GetSpriteCollision(int nsprite) {
    if (nsprite >= engine->numsprites) {
        TLN_SetLastError(TLN_ERR_IDX_SPRITE);
        return false;
    }

    return engine->sprites[nsprite].collision;
}

/*!
 * \brief
 * Disables the sprite so it is not drawn
 *
 * \param nsprite
 * Id of the sprite [0, num_sprites - 1]
 *
 * \remarks
 * A sprite is also automatically disabled when assigned with an invalid
 * spriteste or palette. Disabled sprites are returned by the function
 * TLN_GetAvailableSprite as available
 */
bool TLN_DisableSprite(int nsprite) {
    Sprite* sprite;
    bool enabled;
    if (nsprite >= engine->numsprites) {
        TLN_SetLastError(TLN_ERR_IDX_SPRITE);
        return false;
    }

    sprite = &engine->sprites[nsprite];
    enabled = sprite->ok;
    sprite->ok = false;
    sprite->collision = false;
    sprite->do_collision = false;

    /* disabled: remove from linked list */
    if (enabled == true) {
        debugmsg("%s(%d)\t", __FUNCTION__, nsprite);
        ListUnlinkNode(&engine->list_sprites, nsprite);
    }

    TLN_SetLastError(TLN_ERR_OK);
    return true;
}

/*!
 * \brief
 * Returns runtime info about a given sprite
 *
 * \param nsprite
 * Id of the sprite [0, num_sprites - 1]
 *
 * \param state
 * Pointer to a user-allocated TLN_SpriteState structure to fill with requested
 * data
 */
TLNAPI bool TLN_GetSpriteState(int nsprite, TLN_SpriteState* state) {
    Sprite* sprite;
    if (nsprite >= engine->numsprites) {
        TLN_SetLastError(TLN_ERR_IDX_SPRITE);
        return false;
    }

    if (state == NULL) {
        TLN_SetLastError(TLN_ERR_NULL_POINTER);
        return false;
    }

    sprite = &engine->sprites[nsprite];
    state->x = sprite->x;
    state->y = sprite->y;
    if (sprite->info != NULL) {
        state->w = sprite->info->w;
        state->h = sprite->info->h;
        if (sprite->mode == MODE_SCALING) {
            state->w = (int)(state->w * sprite->sx);
            state->h = (int)(state->h * sprite->sy);
        }
    }
    state->collision = sprite->do_collision;
    state->flags = sprite->flags;
    state->index = sprite->index;
    state->enabled = sprite->ok;
    state->palette = sprite->palette;
    state->spriteset = sprite->spriteset;

    TLN_SetLastError(TLN_ERR_OK);
    return true;
}

/*!
 * \brief Sets the first sprite drawn (beginning of list)
 * \param nsprite Id of the sprite [0, num_sprites - 1]. Must be enabled
 * (visible)
 */
bool TLN_SetFirstSprite(int nsprite) {
    Sprite* sprite;
    List* list;
    ListNode* node;
    int cut1, cut2;
    if (nsprite >= engine->numsprites || !engine->sprites[nsprite].ok ||
        nsprite == engine->list_sprites.first) {
        TLN_SetLastError(TLN_ERR_IDX_SPRITE);
        return false;
    }
    list = &engine->list_sprites;
    sprite = &engine->sprites[nsprite];
    node = &sprite->list_node;

    /* cut points inside the list to rejoin */
    cut1 = node->prev;
    cut2 = node->next;

    /* rejoin segments */
    node->prev = -1;
    node->next = -1;
    ListLinkNodes(list, nsprite, list->first);
    ListLinkNodes(list, cut1, cut2);
    list->first = nsprite;

    debugmsg("%s(%d)\t", __FUNCTION__, nsprite);
    ListPrint(list);
    TLN_SetLastError(TLN_ERR_OK);
    return true;
}

/*!
 * \brief Sets the next sprite to draw after a given sprite, builds list
 * \param nsprite Id of the sprite [0, num_sprites - 1]. Must be enabled
 * (visible) \param next Id of the sprite to draw after Id [0, num_sprites - 1].
 * Must be enabled (visible)
 */
bool TLN_SetNextSprite(int nsprite, int next) {
    List* list;
    int cut1, cut2, cut3;
    if (nsprite >= engine->numsprites || !engine->sprites[nsprite].ok ||
        nsprite == next) {
        TLN_SetLastError(TLN_ERR_IDX_SPRITE);
        return false;
    }

    if (next >= engine->numsprites || !engine->sprites[next].ok) {
        TLN_SetLastError(TLN_ERR_IDX_SPRITE);
        return false;
    }
    list = &engine->list_sprites;

    /* cut points inside the list to rejoin */
    cut1 = ListGetNext(list, nsprite);
    cut2 = ListGetPrev(list, next);
    cut3 = ListGetNext(list, next);

    /* rejoin segments */
    ListLinkNodes(list, nsprite, next);
    ListLinkNodes(list, next, cut1);
    ListLinkNodes(list, cut2, cut3);
    if (list->first == next)
        list->first = cut3;
    if (list->last == nsprite)
        list->last = next;

    debugmsg("%s(%d,%d)\t", __FUNCTION__, nsprite, next);
    ListPrint(list);
    TLN_SetLastError(TLN_ERR_OK);
    return true;
}

/*!
 * \deprecated, use \ref TLN_EnableSpriteFlag (nsprite, FLAG_MASKED, enable)
 * \brief Enables or disables masking for this sprite, if enabled it won't be
 * drawn inside the region set up with TLN_SetSpritesMaskRegion() \param nsprite
 * Id of the sprite to mask [0, num_sprites - 1]. \param enable Enables (true)
 * or disables (false) masking
 */
bool TLN_EnableSpriteMasking(int nsprite, bool enable) {
    return TLN_EnableSpriteFlag(nsprite, FLAG_MASKED, enable);
}

/* normalize clamp in range 0.0f - 1.0f */
static void nclamp(float* v) {
    if (*v < 0.0f)
        *v = 0.0f;
    if (*v > 1.0f)
        *v = 1.0f;
}

/*!
 * \brief Sets sprite pivot point. By default is at (0,0) = top left corner
 * \param nsprite Id of the sprite [0, num_sprites - 1]
 * \param px horizontal normalized value (0.0 = full left, 1.0 = full right)
 * \param py vertical normalized value (0.0 = full top, 1.0 = full bottom)
 * \remarks Sprite pivot is reset automatically to default position after
 * changing the spriteset
 */
bool TLN_SetSpritePivot(int nsprite, float px, float py) {
    Sprite* sprite;
    if (nsprite >= engine->numsprites) {
        TLN_SetLastError(TLN_ERR_IDX_SPRITE);
        return false;
    }

    sprite = &engine->sprites[nsprite];
    if (!sprite->ok) {
        TLN_SetLastError(TLN_ERR_REF_SPRITESET);
        return false;
    }

    nclamp(&px);
    nclamp(&py);
    sprite->ptx = px;
    sprite->pty = py;

    /* also update transform pivot for rotation */
    Point2DSet(&sprite->pivot, px, py);

    if (sprite->has_transform) {
        UpdateSpriteTransform(sprite);
        UpdateSpriteBounds(sprite);
    }

    TLN_SetLastError(TLN_ERR_OK);
    return true;
}

/*!
 * \brief Defines a sprite masking region between the two scanlines. Sprites
 * masked with TLN_EnableSpriteMasking() won't be drawn inside this region.
 * \param top_line Top scaline where masking starts
 * \param bottom_line Bottom scaline where masking ends
 */
void TLN_SetSpritesMaskRegion(int top_line, int bottom_line) {
    engine->sprite_mask_top = top_line;
    engine->sprite_mask_bottom = bottom_line;
}

/* updates clipping rect cache */
void UpdateSprite(Sprite* sprite) {
    int w, h;

    if (!sprite->ok)
        return;

    if (sprite->sx > 1.0)
        w = 0;

    /* sprite source rectangle */
    MakeRect(&sprite->srcrect, 0, 0, sprite->info->w, sprite->info->h);

    /* standard clipping */
    if (sprite->mode == MODE_NORMAL) {
        w = sprite->info->w;
        h = sprite->info->h;

        int x = sprite->x - (int)(w * sprite->ptx);
        int y = sprite->y - (int)(h * sprite->pty);

        /* screen target rectangle */
        MakeRect(&sprite->dstrect, x, y, w, h);

        /* vertical clipping */
        if (sprite->dstrect.y1 < 0) {
            sprite->srcrect.y1 -= sprite->dstrect.y1;
            sprite->dstrect.y1 = 0;
        }
        if (sprite->dstrect.y2 > engine->framebuffer.height) {
            sprite->srcrect.y2 -=
                (sprite->dstrect.y2 - engine->framebuffer.height);
            sprite->dstrect.y2 = engine->framebuffer.height;
        }

        /* horizontal clipping */
        if (sprite->dstrect.x1 < 0) {
            sprite->srcrect.x1 -= sprite->dstrect.x1;
            sprite->dstrect.x1 = 0;
        }
        if (sprite->dstrect.x2 > engine->framebuffer.width) {
            sprite->srcrect.x2 -=
                (sprite->dstrect.x2 - engine->framebuffer.width);
            sprite->dstrect.x2 = engine->framebuffer.width;
        }
    }

    /* clipping scaling */
    else if (sprite->mode == MODE_SCALING) {
        w = (int)(sprite->info->w * sprite->sx);
        h = (int)(sprite->info->h * sprite->sy);

        /* screen target rectangle */
        sprite->dstrect.x1 = sprite->x - (int)(w * sprite->ptx);
        sprite->dstrect.y1 = sprite->y - (int)(h * sprite->pty);
        sprite->dstrect.x2 = sprite->dstrect.x1 + w;
        sprite->dstrect.y2 = sprite->dstrect.y1 + h;

        /* source coords are 16.16 fixed point */
        sprite->srcrect.x1 = int2fix(sprite->srcrect.x1);
        sprite->srcrect.y1 = int2fix(sprite->srcrect.y1);
        sprite->srcrect.x2 = int2fix(sprite->srcrect.x2);
        sprite->srcrect.y2 = int2fix(sprite->srcrect.y2);

        int srcw = sprite->srcrect.x2 - sprite->srcrect.x1;
        int srch = sprite->srcrect.y2 - sprite->srcrect.y1;
        int dstw = sprite->dstrect.x2 - sprite->dstrect.x1;
        int dsth = sprite->dstrect.y2 - sprite->dstrect.y1;

        sprite->dx = srcw / dstw;
        sprite->dy = srch / dsth;

        /* TODO */

        /* clipping vertical */
        if (sprite->dstrect.y1 < 0) {
            sprite->srcrect.y1 -= (sprite->dstrect.y1 * sprite->dy);
            sprite->dstrect.y1 = 0;
        }
        if (sprite->dstrect.y2 > engine->framebuffer.height) {
            sprite->srcrect.y2 -=
                (sprite->dstrect.y2 - engine->framebuffer.height) * sprite->dy;
            sprite->dstrect.y2 = engine->framebuffer.height;
        }

        /* clipping horizontal */
        if (sprite->dstrect.x1 < 0) {
            sprite->srcrect.x1 -= (sprite->dstrect.x1 * sprite->dx);
            sprite->dstrect.x1 = 0;
        }
        if (sprite->dstrect.x2 > engine->framebuffer.width) {
            sprite->srcrect.x2 -=
                (sprite->dstrect.x2 - engine->framebuffer.width) * sprite->dx;
            sprite->dstrect.x2 = engine->framebuffer.width;
        }
    }

    /*
    debugmsg ("Sprite %02d scale=%.02f,%.02f src=[%d,%d,%d,%d]
    dst=[%d,%d,%d,%d]\n", sprite->num, sprite->sx, sprite->sy,
            fix2int(sprite->srcrect.x1), fix2int(sprite->srcrect.y1),
    fix2int(sprite->srcrect.x2), fix2int(sprite->srcrect.y2),
            sprite->dstrect.x1, sprite->dstrect.y1, sprite->dstrect.x2,
    sprite->dstrect.y2);
    */
}

static void SelectSpriteBlitter(Sprite* sprite) {
    const bool scaling = sprite->mode == MODE_SCALING;
    const bool blend = sprite->blend != NULL;

    sprite->blitter = SelectBlitter(true, scaling, blend);
}

/* updates sprite transformation matrix */
static void UpdateSpriteTransform(Sprite* sprite) {
    if (!sprite->has_transform) {
        sprite->mode = MODE_NORMAL;
        sprite->draw = GetSpriteDraw(sprite->mode);
        return;
    }

    Matrix3 temp, composite;
    TLN_Affine* a = &sprite->affine;

    /* calculate pivot offset in sprite space */
    float px = (float)sprite->info->w * sprite->pivot.x;
    float py = (float)sprite->info->h * sprite->pivot.y;

    Matrix3SetIdentity(&composite);

    /* position translation */
    Matrix3SetTranslation(&temp, a->dx, a->dy);
    Matrix3Multiply(&composite, &temp);

    /* pivot translation */
    Matrix3SetTranslation(&temp, -px, -py);
    Matrix3Multiply(&composite, &temp);

    /* scale */
    Matrix3SetScale(&temp, a->sx, a->sy);
    Matrix3Multiply(&composite, &temp);

    /* rotation */
    Matrix3SetRotation(&temp, a->angle);
    Matrix3Multiply(&composite, &temp);

    /* inverse pivot translation */
    Matrix3SetTranslation(&temp, px * 2, py * 2);
    Matrix3Multiply(&composite, &temp);

    /* store inverse transform (screen to sprite space) */
    sprite->transform = composite;
    Matrix3Invert(&sprite->transform);

    sprite->mode = MODE_TRANSFORM;
    sprite->draw = GetSpriteDraw(sprite->mode);
}

/* updates sprite bounds for transformed sprites */
static void UpdateSpriteBounds(Sprite* sprite) {
    if (!sprite->has_transform) {
        /* normal bounds calculation - use existing logic */
        sprite->dstrect.x1 = sprite->x;
        sprite->dstrect.y1 = sprite->y;
        sprite->dstrect.x2 = sprite->x + sprite->info->w;
        sprite->dstrect.y2 = sprite->y + sprite->info->h;
        return;
    }

    /* transform sprite corners to screen space */
    Point2D corners[4];
    Point2DSet(&corners[0], 0, 0);
    Point2DSet(&corners[1], sprite->info->w, 0);
    Point2DSet(&corners[2], sprite->info->w, sprite->info->h);
    Point2DSet(&corners[3], 0, sprite->info->h);

    /* create forward transform by inverting the stored transform */
    Matrix3 forward_transform = sprite->transform;
    Matrix3Invert(&forward_transform);

    /* Find extrema before rounding: truncation clips rotated edge pixels. */
    Point2DMultiply(&corners[0], &forward_transform);
    float min_x = corners[0].x + sprite->x;
    float max_x = min_x;
    float min_y = corners[0].y + sprite->y;
    float max_y = min_y;

    for (int i = 1; i < 4; i++) {
        Point2DMultiply(&corners[i], &forward_transform);
        float screen_x = corners[i].x + sprite->x;
        float screen_y = corners[i].y + sprite->y;
        if (min_x > screen_x)
            min_x = screen_x;
        if (max_x < screen_x)
            max_x = screen_x;
        if (min_y > screen_y)
            min_y = screen_y;
        if (max_y < screen_y)
            max_y = screen_y;
    }

    sprite->dstrect.x1 = (int)floorf(min_x);
    sprite->dstrect.y1 = (int)floorf(min_y);
    /* The scanline bounds are exclusive. Include integer-valued maxima too:
     * rotation can map an included source edge onto the right/bottom edge. */
    sprite->dstrect.x2 = (int)ceilf(max_x) + 1;
    sprite->dstrect.y2 = (int)ceilf(max_y) + 1;
}

void MakeRect(rect_t* rect, int x, int y, int w, int h) {
    rect->x1 = x;
    rect->y1 = y;
    rect->x2 = x + w;
    rect->y2 = y + h;
}
