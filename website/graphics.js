const canvas = document.getElementById("background");
const gl = canvas.getContext("webgl");

// Resize canvas to fill window
function resizeCanvas() {
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;
  gl.viewport(0, 0, gl.drawingBufferWidth, gl.drawingBufferHeight);
}
window.addEventListener("resize", resizeCanvas);
resizeCanvas();

const vsSource = `
  attribute vec2 a_position;
  varying vec2 fragPosition;
  void main(void) {
    fragPosition = a_position.xy;
    gl_Position = vec4(a_position, 0.0, 1.0);
  }
`;

const fsSource = `
  precision mediump float;

  varying vec2 fragPosition;
  uniform vec2 resolution;
  uniform float time;
  uniform vec4 colorA;
  uniform vec4 colorB;

  float smoothplot(float edge, float val, float t, float s) {
      return smoothstep(edge - t - s, edge - t, val) - smoothstep(edge + t, edge + t + s, val);
  }

  mat2 make_rotation_matrix(float ang) {
      return mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang)));
  }

  #define ZOOM 360.0
  #define BLOCK_SIZE 12.0

  void main() {
      float ratio = resolution.x / resolution.y;
      vec2 block = ZOOM / vec2(BLOCK_SIZE * ratio, BLOCK_SIZE);
      vec2 pos = floor(fragPosition * ZOOM / block) * block;
      vec2 uv = pos / ZOOM;
      uv.x *= ratio;

      uv += 0.5;
      vec2 uv2 = uv * make_rotation_matrix(0.4) - 0.5;
      vec2 uv3 = uv * make_rotation_matrix(1.2) - 0.5;
      vec2 uv4 = uv * make_rotation_matrix(1.6) - 0.5;
      uv -= 0.5;
      float waves =
          smoothplot(cos(uv2.y * 3.5 + time * 2.12), uv2.x, 0.0, 0.6 * 3.5) * 0.4 +
              smoothplot(sin(uv3.y * 5.5 + time * 1.88), uv3.x, 0.0, 1.2 * 3.5) * 0.4 +
              smoothplot(sin(uv4.y * 10.0 + time * 1.5), uv4.x, 0.0, 2.0 * 3.5) * 0.16;
      vec4 color = mix(colorA, colorB, waves);
      gl_FragColor = color;
  }
`;

function createShader(type, source) {
  const shader = gl.createShader(type);
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    console.error("Shader compile failed:", gl.getShaderInfoLog(shader));
    gl.deleteShader(shader);
    return null;
  }
  return shader;
}

function createProgram(vsSource, fsSource) {
  const vertexShader = createShader(gl.VERTEX_SHADER, vsSource);
  const fragmentShader = createShader(gl.FRAGMENT_SHADER, fsSource);
  const program = gl.createProgram();
  gl.attachShader(program, vertexShader);
  gl.attachShader(program, fragmentShader);
  gl.linkProgram(program);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    console.error("Program link failed:", gl.getProgramInfoLog(program));
    return null;
  }
  return program;
}

const program = createProgram(vsSource, fsSource);
gl.useProgram(program);

const vertices = new Float32Array([-1.0, -1.0, 1.0, -1.0, -1.0, 1.0, -1.0, 1.0, 1.0, -1.0, 1.0, 1.0]);

const positionBuffer = gl.createBuffer();
gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.STATIC_DRAW);

const positionLoc = gl.getAttribLocation(program, "a_position");
gl.enableVertexAttribArray(positionLoc);
gl.vertexAttribPointer(positionLoc, 2, gl.FLOAT, false, 0, 0);

const FPS = 30;
const FRAME_DURATION = 1000 / FPS;

let lastFrameTime = 0;

function render(time) {
  if (time - lastFrameTime >= FRAME_DURATION) {
    lastFrameTime = time;
    draw(time);
  }
  requestAnimationFrame(render);
}

function draw(time) {
  gl.viewport(0, 0, canvas.width, canvas.height);
  gl.clear(gl.COLOR_BUFFER_BIT);
  gl.uniform1f(gl.getUniformLocation(program, "time"), time * 0.001);
  gl.uniform2f(gl.getUniformLocation(program, "resolution"), canvas.width, canvas.height);
  gl.uniform4f(gl.getUniformLocation(program, "colorA"), 4.0 / 255.0, 0.0, 12.0 / 255.0, 1.0);
  gl.uniform4f(gl.getUniformLocation(program, "colorB"), 80.0 / 255.0, 0.0, 16.0 / 255.0, 1.0);
  gl.drawArrays(gl.TRIANGLES, 0, 6);
}

function onResizeCanvas() {
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;
  gl.viewport(0, 0, gl.drawingBufferWidth, gl.drawingBufferHeight);
  draw(performance.now());
}

window.addEventListener("resize", onResizeCanvas);
render();
