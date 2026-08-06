const VERTEX_SHADER = `
  attribute vec2 a_position;
  attribute vec2 a_texcoord;
  varying vec2 v_texcoord;
  void main() {
    gl_Position = vec4(a_position, 0.0, 1.0);
    v_texcoord = a_texcoord;
  }
`

const FRAGMENT_SHADER = `
  varying highp vec2 v_texcoord;
  uniform sampler2D u_texture;
  void main() {
    gl_FragColor = texture2D(u_texture, v_texcoord);
  }
`

export interface GameView {
  readonly canvas: HTMLCanvasElement
  dispose(): void
  isLost(): boolean
  render(): void
  resize(width: number, height: number): void
}

export interface GameViewOptions {
  preserveDrawingBuffer?: boolean
}

function compileShader(
  gl: WebGLRenderingContext,
  type: number,
  source: string,
): WebGLShader {
  const shader = gl.createShader(type)
  if (!shader) throw new Error('game_view_shader_unavailable')
  gl.shaderSource(shader, source)
  gl.compileShader(shader)
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    throw new Error(gl.getShaderInfoLog(shader) || 'game_view_shader_failed')
  }
  return shader
}

export function createGameView(
  canvas: HTMLCanvasElement,
  options: GameViewOptions = {},
): GameView {
  const gl = canvas.getContext('webgl', {
    alpha: false,
    antialias: false,
    depth: false,
    desynchronized: true,
    failIfMajorPerformanceCaveat: false,
    preserveDrawingBuffer: options.preserveDrawingBuffer === true,
    stencil: false,
  }) as WebGLRenderingContext | null
  if (!gl) throw new Error('game_view_unavailable')

  let lost = false
  let disposed = false
  const onContextLost = (event: Event) => {
    event.preventDefault()
    lost = true
    console.error('[Camera] Game-view WebGL context lost.')
  }
  canvas.addEventListener(
    'webglcontextlost',
    onContextLost as EventListener,
    false,
  )

  const program = gl.createProgram()
  if (!program) throw new Error('game_view_program_unavailable')
  gl.attachShader(program, compileShader(gl, gl.VERTEX_SHADER, VERTEX_SHADER))
  gl.attachShader(
    program,
    compileShader(gl, gl.FRAGMENT_SHADER, FRAGMENT_SHADER),
  )
  gl.linkProgram(program)
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    throw new Error(gl.getProgramInfoLog(program) || 'game_view_program_failed')
  }
  gl.useProgram(program)

  const positionLocation = gl.getAttribLocation(program, 'a_position')
  const texcoordLocation = gl.getAttribLocation(program, 'a_texcoord')
  if (positionLocation < 0 || texcoordLocation < 0) {
    throw new Error('game_view_attributes_unavailable')
  }

  const positionBuffer = gl.createBuffer()
  gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer)
  gl.bufferData(
    gl.ARRAY_BUFFER,
    new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]),
    gl.STATIC_DRAW,
  )
  gl.enableVertexAttribArray(positionLocation)
  gl.vertexAttribPointer(positionLocation, 2, gl.FLOAT, false, 0, 0)

  const texcoordBuffer = gl.createBuffer()
  gl.bindBuffer(gl.ARRAY_BUFFER, texcoordBuffer)
  gl.bufferData(
    gl.ARRAY_BUFFER,
    new Float32Array([0, 0, 1, 0, 0, 1, 1, 1]),
    gl.STATIC_DRAW,
  )
  gl.enableVertexAttribArray(texcoordLocation)
  gl.vertexAttribPointer(texcoordLocation, 2, gl.FLOAT, false, 0, 0)

  const texture = gl.createTexture()
  gl.bindTexture(gl.TEXTURE_2D, texture)
  gl.texImage2D(
    gl.TEXTURE_2D,
    0,
    gl.RGBA,
    1,
    1,
    0,
    gl.RGBA,
    gl.UNSIGNED_BYTE,
    new Uint8Array([0, 0, 0, 255]),
  )
  gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
  gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
  gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
  gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
  gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.MIRRORED_REPEAT)
  gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
  gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
  gl.uniform1i(gl.getUniformLocation(program, 'u_texture'), 0)

  return {
    canvas,
    dispose() {
      if (disposed) return
      disposed = true
      canvas.removeEventListener(
        'webglcontextlost',
        onContextLost as EventListener,
        false,
      )
      gl.getExtension('WEBGL_lose_context')?.loseContext()
    },
    isLost: () => lost,
    render() {
      if (disposed || lost) return
      gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
      gl.finish()
    },
    resize(width: number, height: number) {
      if (disposed || lost) return
      canvas.width = width
      canvas.height = height
      gl.viewport(0, 0, width, height)
    },
  }
}
