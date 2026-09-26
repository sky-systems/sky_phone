const platforms = ['feather', 'fliptok', 'picstagram', 'weazel-news']
const posts = Object.fromEntries(
  platforms.map((platform, index) => [
    platform,
    [
      {
        id: `550e8400-e29b-41d4-a716-44665544000${index}`,
        author: 'preview_author',
        body: `Preview moderation post for ${platform}`,
        createdAt: '2026-09-25 12:00:00',
      },
    ],
  ]),
)

function socialPosts(data) {
  if (!posts[data.platform]) return { success: false, error: 'invalid_request' }
  const query = String(data.query ?? '').toLowerCase()
  const filtered = posts[data.platform].filter((post) =>
    [post.body, post.author, post.id].some((text) =>
      text.toLowerCase().includes(query),
    ),
  )
  const offset = Number(data.page ?? 0) * 50
  return {
    success: true,
    data: {
      items: filtered.slice(offset, offset + 50),
      hasMore: filtered.length > offset + 50,
    },
  }
}

function deleteSocialPost(data) {
  const items = posts[data.platform]
  const index = items?.findIndex((post) => post.id === data.id) ?? -1
  if (index < 0) return { success: false, error: 'not_found' }
  items.splice(index, 1)
  return { success: true }
}
module.exports = { socialPosts, deleteSocialPost }
