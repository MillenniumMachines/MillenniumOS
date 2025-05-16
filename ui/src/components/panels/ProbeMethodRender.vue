
/**
 * 
 * JSFiddle to render a 3D cube with the 4 sides colored blue and the other 2 sides dark.
 let camera, scene, renderer, cube

init()

function init() {
  camera = new THREE.PerspectiveCamera(
    50,
    window.innerWidth / window.innerHeight,
    0.01,
    10,
  )
  camera.position.z = 3
  camera.position.x = -3
  camera.position.y = 1.5
  camera.rotation.z = -0.35
  camera.rotation.y = -1
  camera.rotation.x = -0.5

  scene = new THREE.Scene({ background: new THREE.Color(0x1e1e1e) })

  const piece = new THREE.BoxGeometry(2, 0.75, 2).toNonIndexed()
  const material = new THREE.MeshBasicMaterial({
    vertexColors: true,
  })
  const positionAttribute = piece.getAttribute("position")
  const colors = []

  const color = new THREE.Color()
  //for (let i = 0; i <= 6; i += 6) {
  for (let i = 0; i < positionAttribute.count; i += 6) {
    if ([1, 2, 5, 6].includes(i / 6 + 1)) {
      color.setHex(0x2196f3)
    } else {
      color.setHex(0x1e1e1e)
    }

    colors.push(color.r, color.g, color.b)
    colors.push(color.r, color.g, color.b)
    colors.push(color.r, color.g, color.b)

    colors.push(color.r, color.g, color.b)
    colors.push(color.r, color.g, color.b)
    colors.push(color.r, color.g, color.b)
  } // for

  // define the new attribute
  piece.setAttribute("color", new THREE.Float32BufferAttribute(colors, 3))

  cube = new THREE.Mesh(piece, material)
  scene.add(cube)

  var objectEdges = new THREE.LineSegments(
    new THREE.EdgesGeometry(cube.geometry),
    new THREE.LineBasicMaterial({ color: 0x787878, linewidth: 1 }),
  )
  cube.add(objectEdges)

  renderer = new THREE.WebGLRenderer({
    antialias: true,
  })
  renderer.setSize(window.innerWidth, window.innerHeight)
  renderer.setAnimationLoop(animation)
  document.body.appendChild(renderer.domElement)
}

function animation(time) {
  // cube.rotation.x = time / 2000;
  cube.rotation.y = time / 2000

  renderer.render(scene, camera)
}

*/