export function colorLuminance(channels: readonly number[]): number {
  return channels.reduce((sum, channel, index) => {
    const value = channel / 255
    const linear =
      value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4
    return sum + linear * [0.2126, 0.7152, 0.0722][index]!
  }, 0)
}
