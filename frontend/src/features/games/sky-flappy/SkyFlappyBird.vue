<template>
  <svg
    class="sky-flappy-bird"
    viewBox="0 0 104 72"
    xmlns="http://www.w3.org/2000/svg"
    aria-hidden="true"
  >
    <defs>
      <linearGradient
        id="sky-bird-body"
        x1="20"
        y1="24"
        x2="84"
        y2="54"
        gradientUnits="userSpaceOnUse"
      >
        <stop stop-color="#5fc1d1" />
        <stop offset="0.58" stop-color="#287d99" />
        <stop offset="1" stop-color="#16546f" />
      </linearGradient>
      <linearGradient
        id="sky-bird-wing"
        x1="40"
        y1="12"
        x2="61"
        y2="55"
        gradientUnits="userSpaceOnUse"
      >
        <stop stop-color="#b5e5e7" />
        <stop offset="0.48" stop-color="#579eb0" />
        <stop offset="1" stop-color="#245f78" />
      </linearGradient>
    </defs>

    <g class="sky-flappy-bird__far-wing">
      <path d="M50 38C39 29 30 15 34 5c10 4 22 16 29 31Z" />
      <path d="M39 13c7 5 14 13 19 22" />
    </g>
    <path class="sky-flappy-bird__tail" d="M29 36 5 25l12 15L3 49l29-4Z" />
    <path
      class="sky-flappy-bird__body"
      d="M20 40c8-12 24-17 45-14 12 1 20 7 25 14-8 10-21 13-36 12-15-1-27-4-34-12Z"
    />
    <path
      class="sky-flappy-bird__belly"
      d="M24 43c13 4 31 5 45 1 7-2 12-5 16-9 2 2 4 4 5 6-8 10-21 13-36 12-13-1-24-4-30-10Z"
    />
    <path
      class="sky-flappy-bird__neck"
      d="M67 27c7-8 18-9 24-2 4 4 4 10 1 16-8 1-16-3-23-9Z"
    />

    <g class="sky-flappy-bird__wing">
      <path
        class="sky-flappy-bird__wing-shape"
        d="M52 38C42 31 35 18 40 6c10 5 20 16 27 29-1 8-7 17-19 25 2-8 3-15 4-22Z"
      />
      <path
        class="sky-flappy-bird__feather"
        d="M44 16c8 7 14 15 18 23M46 27c7 5 11 11 13 18M48 39c4 3 7 6 8 10"
      />
    </g>

    <path
      class="sky-flappy-bird__face"
      d="M76 26c5-5 12-4 16 1-4 1-7 4-9 8-4-1-7-4-7-9Z"
    />
    <circle class="sky-flappy-bird__eye-ring" cx="86" cy="27" r="3.1" />
    <circle class="sky-flappy-bird__eye" cx="86.7" cy="27" r="1.45" />
    <path class="sky-flappy-bird__beak" d="m91 31 12 5-12 4c2-3 2-6 0-9Z" />
  </svg>
</template>
