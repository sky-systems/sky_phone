import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const read = (path: string) =>
  readFileSync(new URL(path, import.meta.url), 'utf8')

const server = read('../../sky_phone/source/server/skypic.lua')
const migration = read('../../sky_phone/source/server/db_migrate.lua')
const install = read('../../sky_phone/sql/install.sql')
const media = read('../../sky_phone/source/server/media.lua')
const config = read('../../sky_phone/config/config.lua')
const mediaUtils = read('./utils/media.ts')
const fallbackLocales = read('./stores/phone.ts')
const englishLocale = read('../../sky_phone/config/locales/en.lua')
const germanLocale = read('../../sky_phone/config/locales/de.lua')
const mockServer = read('../testserver/index.cjs')

function block(source: string, startMarker: string, endMarker: string): string {
  const start = source.indexOf(startMarker)
  const end = source.indexOf(endMarker, start + startMarker.length)
  expect(start, `missing ${startMarker}`).toBeGreaterThanOrEqual(0)
  expect(end, `missing ${endMarker}`).toBeGreaterThan(start)
  return source.slice(start, end)
}

function migrationTable(name: string): string {
  return block(migration, `name = "sky_phone_skypic_${name}"`, 'tableOptions =')
}

function installTable(name: string): string {
  return block(
    install,
    `CREATE TABLE IF NOT EXISTS \`sky_phone_skypic_${name}\``,
    ') ENGINE=InnoDB',
  )
}

const callbacks = [
  'bootstrap',
  'create-profile',
  'delete-account',
  'update-profile',
  'search',
  'add-friend',
  'respond-friend',
  'remove-friend',
  'block',
  'send-snap',
  'open-snap',
  'replay-snap',
  'publish-story',
  'stories',
  'view-story',
  'story-viewers',
  'remove-story',
  'spotlight-feed',
  'publish-spotlight',
  'view-spotlight',
  'like-spotlight',
  'spotlight-comments',
  'comment-spotlight',
  'delete-spotlight-comment',
  'remove-spotlight',
  'report-spotlight',
  'thread',
  'send-message',
  'mark-thread',
  'save-message',
  'delete-message',
] as const

const tables: Record<string, string[]> = {
  profiles: [
    'id',
    'account_id',
    'handle',
    'display_name',
    'bio',
    'avatar_media_id',
    'avatar_seed',
    'story_privacy',
    'quick_add',
    'allow_story_replies',
    'snap_score',
    'friend_count',
    'status',
    'created_at',
    'updated_at',
  ],
  friendships: [
    'id',
    'profile_a_id',
    'profile_b_id',
    'requested_by_id',
    'status',
    'profile_a_last_snap_on',
    'profile_b_last_snap_on',
    'streak_updated_on',
    'streak_count',
    'best_streak',
    'accepted_at',
    'created_at',
    'updated_at',
  ],
  blocks: ['blocker_profile_id', 'blocked_profile_id', 'created_at'],
  messages: [
    'id',
    'friendship_id',
    'sender_profile_id',
    'recipient_profile_id',
    'message_type',
    'body',
    'caption',
    'overlay_text',
    'overlay_color',
    'media_id',
    'view_seconds',
    'allow_replay',
    'read_at',
    'opened_at',
    'replayed_at',
    'saved_at',
    'expires_at',
    'sender_deleted_at',
    'recipient_deleted_at',
    'deleted_at',
    'created_at',
  ],
  stories: [
    'id',
    'profile_id',
    'media_id',
    'caption',
    'overlay_text',
    'overlay_color',
    'view_seconds',
    'privacy',
    'status',
    'expires_at',
    'created_at',
    'updated_at',
  ],
  story_views: ['story_id', 'viewer_profile_id', 'viewed_at'],
  spotlights: [
    'id',
    'profile_id',
    'media_id',
    'caption',
    'overlay_text',
    'overlay_color',
    'kind',
    'ad_headline',
    'comments_enabled',
    'status',
    'expires_at',
    'created_at',
    'updated_at',
  ],
  spotlight_views: ['spotlight_id', 'viewer_profile_id', 'viewed_at'],
  spotlight_likes: ['spotlight_id', 'profile_id', 'created_at'],
  spotlight_comments: [
    'id',
    'spotlight_id',
    'profile_id',
    'body',
    'status',
    'created_at',
  ],
  spotlight_reports: [
    'spotlight_id',
    'reporter_profile_id',
    'reason',
    'details',
    'status',
    'created_at',
  ],
}

describe('SkyPic backend contracts', () => {
  it('keeps migration and clean-install schemas synchronized', () => {
    for (const [table, columns] of Object.entries(tables)) {
      const migrationSource = migrationTable(table)
      const installSource = installTable(table)
      for (const column of columns) {
        expect(migrationSource, `${table}.${column} migration`).toContain(
          `name = "${column}"`,
        )
        expect(installSource, `${table}.${column} install`).toContain(
          `\`${column}\``,
        )
      }
    }

    for (const table of ['messages', 'stories', 'spotlights']) {
      expect(migrationTable(table)).toContain('ON DELETE RESTRICT')
      expect(installTable(table)).toContain('ON DELETE RESTRICT')
    }
  })

  it('backfills every normalized unique key on existing databases', () => {
    const afterMigrate = migration.slice(
      migration.indexOf('Bridge.Database.Migrate("sky_phone", schema)'),
    )
    for (const index of [
      'uniq_sky_phone_skypic_profile_account',
      'uniq_sky_phone_skypic_profile_handle',
      'uniq_sky_phone_skypic_friend_pair',
    ]) {
      expect(afterMigrate).toContain(`"${index}"`)
    }
    expect(
      afterMigrate.match(/\{ unique = true \}/g)?.length ?? 0,
    ).toBeGreaterThanOrEqual(3)
  })

  it('registers the complete canonical callback surface', () => {
    for (const callback of callbacks) {
      expect(server).toContain(
        `Bridge.Callbacks.Register("sky_phone:skypic:${callback}"`,
      )
    }
    expect(server).toContain('Bridge.Database.AfterMigration("sky_phone"')
  })

  it('validates all submitted media through the owned-media resolver', () => {
    const editor = block(
      server,
      'local function editor_payload',
      'Bridge.Callbacks.Register("sky_phone:skypic:thread"',
    )
    expect(editor).toContain(
      'SkyPhoneMedia.ResolveOwnedMedia(source, media_id, data.mediaType)',
    )
    expect(
      server.match(/SkyPhoneMedia\.ResolveOwnedMedia\(/g)?.length,
    ).toBeGreaterThanOrEqual(3)
    expect(server).toContain(
      'SkyPhoneMedia.ResolveOwnedMedia(source, avatar_media_id, "photo")',
    )
  })

  it('validates dense photo batches before creating their cartesian snap set', () => {
    const editors = block(
      server,
      'local function snap_editor_payloads',
      'Bridge.Callbacks.Register("sky_phone:skypic:thread"',
    )
    expect(config).toContain('MaximumMediaPerSend = 10')
    expect(config).toContain('MaximumSnapMessagesPerSend = 40')
    expect(editors).toContain('count > limit("MaximumMediaPerSend", 10)')
    expect(editors).toContain('if key_count ~= count then')
    expect(editors).toContain('seen[media_id]')
    expect(editors).toContain('mediaType = "photo"')
    expect(server).toContain(
      'SkyPhoneMedia.ResolveOwnedMedia(source, media_id, data.mediaType)',
    )

    const sendSnap = block(
      server,
      'Bridge.Callbacks.Register("sky_phone:skypic:send-snap"',
      'Bridge.Callbacks.Register("sky_phone:skypic:open-snap"',
    )
    expect(sendSnap).toContain(
      'raw_media_count > limit("MaximumMediaPerSend", 10)',
    )
    expect(sendSnap).toContain(
      'message_count > limit("MaximumSnapMessagesPerSend", 40)',
    )
    expect(sendSnap).toContain('editor = editor')
    expect(sendSnap).toContain('Bridge.Database.Transaction(statements)')
    expect(sendSnap).toContain('SELECT COUNT(*) FROM')
    expect(sendSnap).toContain(') <> ?')
    expect(sendSnap).toContain(
      'assertion_params[#assertion_params + 1] = #entries',
    )
    expect(sendSnap).toContain('message_ids[#message_ids + 1] = entry.id')
    expect(sendSnap).toContain(
      'local sent = load_snap_metadata(message_ids, profile.profile_id)',
    )

    expect(mockServer).toContain('function skyPicMediaItems(body)')
    expect(mockServer).toContain('submitted.length > 10')
    expect(mockServer).toContain('seen.has(mediaId)')
    expect(mockServer).toContain('mediaItems.length * recipients.length > 40')
  })

  it('maintains reciprocal UTC-day streaks and returns reconciled values', () => {
    const friendshipMigration = migrationTable('friendships')
    const friendshipInstall = installTable('friendships')
    const friends = block(
      server,
      'local function list_friends',
      'local function list_requests',
    )
    const conversations = block(
      server,
      'local function list_conversations',
      'Bridge.Callbacks.Register("sky_phone:skypic:bootstrap"',
    )
    const metadata = block(
      server,
      'local function load_snap_metadata',
      'local function opened_snap_from_row',
    )
    const sendSnap = block(
      server,
      'Bridge.Callbacks.Register("sky_phone:skypic:send-snap"',
      'Bridge.Callbacks.Register("sky_phone:skypic:open-snap"',
    )

    for (const schema of [friendshipMigration, friendshipInstall]) {
      expect(schema).toContain('profile_a_last_snap_on')
      expect(schema).toContain('profile_b_last_snap_on')
      expect(schema).toContain('streak_updated_on')
      expect(schema).toContain('streak_count')
      expect(schema).toContain('best_streak')
      expect(schema).toContain('idx_sky_phone_skypic_streaks')
    }

    expect(sendSnap).toContain('SET %s = UTC_DATE()')
    expect(sendSnap).toContain(
      'SELECT 1 FROM `sky_phone_skypic_messages` message WHERE message.`id` = ?',
    )
    expect(sendSnap).toContain('friendship.profile_a_id == profile.profile_id')
    expect(sendSnap).toContain('`profile_a_last_snap_on` = UTC_DATE()')
    expect(sendSnap).toContain('`profile_b_last_snap_on` = UTC_DATE()')
    expect(sendSnap).toContain(
      '`streak_updated_on` = DATE_SUB(UTC_DATE(), INTERVAL 1 DAY)',
    )
    expect(sendSnap).toContain(
      '`streak_updated_on` IS NULL OR `streak_updated_on` < UTC_DATE()',
    )
    expect(sendSnap).toContain('Bridge.Database.Transaction(statements)')

    for (const serializer of [friends, conversations, metadata]) {
      expect(serializer).toContain(
        '`streak_updated_on` < DATE_SUB(UTC_DATE(), INTERVAL 1 DAY)',
      )
      expect(serializer).toContain(
        'THEN 0 ELSE friendship.`streak_count` END AS `streak_count`',
      )
      expect(serializer).toContain('friendship.`best_streak`')
    }
    expect(metadata).toContain("friendship.`status` = 'accepted'")
    expect(metadata).toContain(
      'snap.streakCount = tonumber(row.streak_count) or 0',
    )
    expect(metadata).toContain(
      'snap.bestStreak = tonumber(row.best_streak) or 0',
    )

    expect(server).toContain('SET `streak_count` = 0')
    expect(server).toContain(
      "WHERE `status` = 'accepted' AND `streak_count` > 0",
    )
  })

  it('keeps browser payload limits and profile creation aligned with production', () => {
    expect(config).toContain('CaptionMaxLength = 160')
    expect(server).toContain('valid_integer(data.avatarSeed, 1, 2147483647)')
    expect(mockServer).toContain('candidate <= 2_147_483_647')
    expect(mockServer).toContain(
      'return [...caption].length <= 160 ? caption : null',
    )
    expect(mockServer).toContain("error: 'invalid_avatar_seed'")
    expect(mockServer).toContain("error: 'invalid_caption'")
    expect(mockServer).toContain('value.length > 20')
    expect(mockServer).toContain("error: 'message_too_long'")
    expect(mockServer).not.toContain('body.slice(0, 1000)')
    expect(mockServer).toContain("error: 'profile_exists'")
    expect(mockServer).toContain(
      "const onboardingScenario = testScenario === 'skypic-onboarding'",
    )
    expect(mockServer).toContain(
      'onboardingScenario && skyPicOnboardingProfile',
    )
    expect(mockServer).toContain('const profile = skyPicOnboardingProfile')
    expect(mockServer).toContain('suggestions: profile')
  })

  it('deletes only the confirmed SkyPic account and silently refreshes peers', () => {
    const deletion = block(
      server,
      'Bridge.Callbacks.Register("sky_phone:skypic:delete-account"',
      'Bridge.Callbacks.Register("sky_phone:skypic:update-profile"',
    )
    expect(deletion).toContain('data.confirmed ~= true')
    expect(deletion).toContain('error = "confirmation_required"')
    expect(deletion).toContain('Bridge.Database.Transaction({')
    expect(deletion).toContain('SET peer.')
    expect(deletion).toContain('friend_count')
    expect(deletion).toContain(' > 0, peer.')
    expect(deletion).toContain('- 1, 0')
    expect(deletion).toContain('DELETE FROM')
    expect(deletion).toContain('sky_phone_skypic_profiles')
    expect(deletion).toContain('sky_phone_skypic_blocks')
    expect(deletion).toContain('UNION ALL')
    expect(deletion).toContain(
      "AND status = 'active'".replace(
        'status',
        String.fromCharCode(96) + 'status' + String.fromCharCode(96),
      ),
    )
    expect(deletion).not.toContain('sky_phone_media')
    expect(deletion).toContain('"sky_phone:skypic:changed"')
    expect(deletion).not.toContain('"sky_phone:skypic:new"')
    expect(mockServer).toContain("if (endpoint === 'skypic:delete-account')")
    expect(mockServer).toContain("error: 'confirmation_required'")
  })

  it('keeps direct snap secrets out of bootstrap and thread serializers', () => {
    const safeSnap = block(
      server,
      'local function safe_snap_from_row',
      'local function text_message_from_row',
    )
    for (const secret of [
      'url = row.url',
      'caption =',
      'textOverlay =',
      'overlayColor =',
    ]) {
      expect(safeSnap).not.toContain(secret)
    }

    const thread = block(
      server,
      'local function list_thread',
      'local function editor_payload',
    )
    expect(thread).not.toContain('message.`caption`')
    expect(thread).not.toContain('message.`overlay_text`')
    expect(thread).not.toContain('message.`overlay_color`')
    expect(thread).not.toContain('message.`media_id`')

    const storyList = block(
      server,
      'local function list_stories',
      'local function list_conversations',
    )
    expect(storyList).not.toContain('story.`caption`')
    expect(storyList).not.toContain('story.`overlay_text`')
    expect(storyList).not.toContain('story.`overlay_color`')
    expect(storyList).not.toContain('story.`media_id`')
    expect(storyList).toContain(
      'ORDER BY (story.`profile_id` = ?) DESC, story.`created_at` DESC, story.`id` DESC',
    )
    expect(storyList).not.toContain(
      'ORDER BY (story.`profile_id` = ?) DESC, `seen`',
    )
  })

  it('releases snap contents only after atomic one-time state changes', () => {
    const open = block(
      server,
      'Bridge.Callbacks.Register("sky_phone:skypic:open-snap"',
      'Bridge.Callbacks.Register("sky_phone:skypic:replay-snap"',
    )
    expect(open).toContain('message.`opened_at` IS NULL')
    expect(open).toContain('message.`recipient_profile_id` = ?')
    expect(open).toContain(
      'IF(message.`allow_replay` = 1, ?, message.`view_seconds`)',
    )
    expect(open.indexOf('affected_rows(result) ~= 1')).toBeLessThan(
      open.indexOf('released_snap('),
    )

    const replay = block(
      server,
      'Bridge.Callbacks.Register("sky_phone:skypic:replay-snap"',
      'local function own_story_metadata',
    )
    expect(replay).toContain('message.`allow_replay` = 1')
    expect(replay).toContain('message.`opened_at` IS NOT NULL')
    expect(replay).toContain('message.`replayed_at` IS NULL')
    expect(replay.indexOf('affected_rows(result) ~= 1')).toBeLessThan(
      replay.indexOf('released_snap('),
    )
  })

  it('atomically protects every database media reference before remote delete', () => {
    const guard = block(
      media,
      'local function is_referenced_by_skypic',
      'local function delete_owned_media',
    )
    expect(guard).toContain('FROM `sky_phone_skypic_messages`')
    expect(guard).toContain('FROM `sky_phone_skypic_stories`')
    expect(guard).toContain('FROM `sky_phone_skypic_spotlights`')
    expect(guard).not.toContain('`expires_at` >')
    expect(guard).not.toContain("`status` = 'active'")

    const deletion = block(
      media,
      'local function delete_owned_media',
      'RegisterNetEvent("sky_phone:media:delete"',
    )
    expect(deletion).toContain('return false, "media_in_use"')
    expect(deletion).toContain('AND NOT EXISTS (')
    expect(deletion).toContain('if affected_rows(result) ~= 1 then')
    expect(deletion.indexOf('DELETE FROM `sky_phone_media`')).toBeLessThan(
      deletion.indexOf('delete_remote_file(row.remote_id)'),
    )
    expect(mediaUtils).toContain("'media_in_use'")
    expect(fallbackLocales).toMatch(
      /media_in_use:\s*'This media is still used by SkyPic and cannot be deleted yet\.'/,
    )
    expect(englishLocale).toContain(
      'media_in_use = "This media is still used by SkyPic and cannot be deleted yet."',
    )
    expect(germanLocale).toContain(
      'media_in_use = "Dieses Medium wird noch von SkyPic verwendet und kann noch nicht gelöscht werden."',
    )
  })

  it('enforces viewer-specific deletion and bounded expiry cleanup', () => {
    expect(server).toContain('`sender_deleted_at`')
    expect(server).toContain('`recipient_deleted_at`')
    expect(server).toContain('SET `deleted_at` = CURRENT_TIMESTAMP(6)')
    expect(server).toContain('AND `sender_profile_id` = ?')
    expect(server).toContain('Wait(limit("CleanupIntervalSeconds", 45) * 1000)')
    expect(config).toContain('StoryLifetimeSeconds = 24 * 60 * 60')
    expect(config).toContain('ReplayWindowSeconds = 5 * 60')
    expect(config).toContain('TextAfterReadLifetimeSeconds = 24 * 60 * 60')
  })

  it('gates optional story replies in the message insert itself', () => {
    const sendMessage = block(
      server,
      'Bridge.Callbacks.Register("sky_phone:skypic:send-message"',
      'Bridge.Callbacks.Register("sky_phone:skypic:mark-thread"',
    )
    expect(sendMessage).toContain('local story_id =')
    expect(sendMessage).toContain('story.`profile_id` = ?')
    expect(sendMessage).toContain("story.`status` = 'active'")
    expect(sendMessage).toContain('story.`expires_at` > CURRENT_TIMESTAMP(6)')
    expect(sendMessage).toContain('author.`allow_story_replies` = 1')
    expect(sendMessage).toContain("friendship.`status` = 'accepted'")
    expect(sendMessage).toContain('NOT EXISTS (')
    expect(sendMessage).toContain('story_id and "story_reply" or "message"')
  })

  it('returns a rich outgoing friend request from add-friend', () => {
    const addFriend = block(
      server,
      'Bridge.Callbacks.Register("sky_phone:skypic:add-friend"',
      'Bridge.Callbacks.Register("sky_phone:skypic:respond-friend"',
    )
    expect(addFriend).toContain('target.friendshipId = friendship_id')
    expect(addFriend).toContain('target.friendshipStatus = "outgoing"')
    expect(addFriend).toContain('direction = "outgoing"')
    expect(addFriend).toContain('profile = target')
  })

  it('enforces the friend limit atomically while accepting requests', () => {
    const respondFriend = block(
      server,
      'Bridge.Callbacks.Register("sky_phone:skypic:respond-friend"',
      'Bridge.Callbacks.Register("sky_phone:skypic:remove-friend"',
    )
    expect(respondFriend).toContain(
      'profile_a.`friend_count` = profile_a.`friend_count` + 1',
    )
    expect(respondFriend).toContain(
      'profile_b.`friend_count` = profile_b.`friend_count` + 1',
    )
    expect(respondFriend).toContain('profile_a.`friend_count` < ?')
    expect(respondFriend).toContain('profile_b.`friend_count` < ?')
    expect(respondFriend).toContain(
      'return { success = false, error = "friend_limit_reached" }',
    )
  })

  it('keeps pending requests out of quick-add suggestions', () => {
    const profiles = block(
      server,
      'local function list_profiles',
      'local function list_conversations',
    )
    expect(profiles).toContain(
      'filters[#filters + 1] = "friendship.`id` IS NULL"',
    )
    expect(profiles).not.toContain("friendship.`status` = 'pending'")
  })
})
