// letter tetris game
// 2014.12.26
// Isaac Reilly

/* todo:
 configure keys, word lengths
 other digraphs?
 */

int GridSize = 50;
int GridHeight = 13;
int GridWidth = 5;
color TextColor = color(0);
color GhostlyTextColor = color(255, 255, 0);
Grid G;
int last_update;
IntDict words;
int points;
int Margin = 40;
String preview = "";
Status status;
WordList complete_words;
String[] word_list;
int SideBarWidth = int(GridSize*3);
PImage background_img, body_img, bubble_img;
boolean CHEAT_MODE = false;
Minim minim;
AudioPlayer player;
StringList letter_buffer;

String[] text_snippets = {
  "q", "j", "l", "t", "v", "p", "f", "o", "i", "b", "n", "w", "y", "x", "m", "z", "e", "s", "k", "u", "d", "r", "a", "qu", "h", "g", "c"
};
int[] frequencies = {
  42, 2674, 84619, 104045, 15429, 46600, 20030, 103497, 140312, 30124, 106772, 12418, 25870, 4761, 44855, 7601, 182743, 150216, 14451, 52109, 54873, 112468, 120954, 2542, 36764, 43537, 64170
};
int total_frequency;

void setup() {
  size((GridWidth*GridSize)+(Margin*2)+SideBarWidth, 
  (GridHeight*GridSize)+(Margin*2));
  textFont(loadFont("Kefa-Bold-48.vlw"));


  import ddf.minim.spi.*;
  import ddf.minim.signals.*;
  import ddf.minim.*;
  import ddf.minim.analysis.*;
  import ddf.minim.ugens.*;
  import ddf.minim.effects.*;
  minim = new Minim(this);
  player = minim.loadFile("track1.wav");
  player.loop();


  frame.setTitle("Bear Words");

  words = new IntDict();
  word_list = loadStrings("four_letter_words.txt");
  for (String word : word_list) {
    words.set(word, 1);
  }
  if (CHEAT_MODE) {
    words.set("xxxx", 1);
    words.set("oooo", 1);
  }
  letter_buffer = new StringList();

  for (int i = 0; i < frequencies.length; i++) {
    total_frequency += frequencies[i];
  }

  status = status.MENU;

  background_img = loadImage("grid_background.png");
  body_img = loadImage("grid_body.png");
  bubble_img = loadImage("bubble.png");
}

void new_game() {
  pick_text(); // to load preview for real 'first' use
  G = new Grid();
  G.x = Margin;
  G.y = Margin;
  G.init(GridWidth, GridHeight);
  G.next_block(); // spawn first Block
  points = 0;
  status = status.PLAYING;
  last_update = millis();
  complete_words = new WordList(int(Margin*1.5)+GridSize*GridWidth, 
  Margin, GridHeight);
}

void draw() {
  if (status == status.PLAYING) {
    background(0);
    image(background_img, 0, 0, width, height);
    draw_points();
    draw_preview();
    draw_quit_button();
    G.make_blocks_fall_if_loose();
    G.draw();
    complete_words.update();
    complete_words.draw();
    if (millis() - 1800 < last_update) {
      return;
    }
    last_update = millis();
    G.update();
    G.draw();
  } else if (status == status.GAME_OVER) {
    background(0);
    image(background_img, 0, 0, width, height);
    draw_points();
    draw_preview();
    G.make_blocks_fall_if_loose();
    G.draw(); // without updating
    complete_words.update();
    complete_words.draw();
    draw_game_over();
  } else if (status == status.MENU) {
    draw_menu();
  }
}

void keyPressed() {
  if (status == status.PLAYING) {
    if (key == CODED) {
      if (keyCode == LEFT) {
        G.active_left();
      } else if (keyCode == RIGHT) {
        G.active_right();
      } else if (keyCode == DOWN) {
        G.active_drop();
      }
    } else if (key == 'a' ||
      key == 'A' ||
      key == 'l' ||
      key == 'L' ||
      key == 'j' ||
      key == 'J') {
      G.active_left();
    } else if (key == 'f' ||
      key == 'F' ||
      key == 'r' ||
      key == 'R' ||
      key == ';' ||
      key == ':' ||
      key == '\'' ||
      key == '"') {
      G.active_right();
    } else if (key == 'd' ||
      key == 'D' ||
      key == ' ' ||
      key == 'k' ||
      key == 'K') {
      G.active_drop();
    } else if (key == 'x' ||
      key == 'X' ||
      key == 'q' ||
      key == 'Q') {
      status = status.GAME_OVER;
    }
  } else if (status == status.GAME_OVER) {
    if (key != CODED) {
      status = status.MENU;
    }
  } else if (status == status.MENU) {
    if (key != CODED) {
      new_game();
    }
  }
}

void mousePressed() {
  if (status == status.PLAYING) {
    if (mouseX > width-100 && mouseY < 100) {
      status = status.GAME_OVER;
    } else if (mouseY > int(height*0.6)) {
      G.active_drop();
    } else if (mouseX < int(width/3)) {
      G.active_left();
    } else {
      G.active_right();
    }
  } else if (status == status.GAME_OVER) {
    status = status.MENU;
  } else if (status == status.MENU) {
    new_game();
  }
}

class Grid {
  int x, y;
  Block[][] grid;
  int active_i = -1, active_j = -1;
  int width, height, spawn_x;
  ArrayList<Block> ghosts;

  void init(int w, int h) {
    this.width = w;
    this.height = h;
    this.grid = new Block[this.width][this.height];
    this.spawn_x = round(this.width/2);
    this.ghosts = new ArrayList<Block>();
  }

  void active_left() {
    if (this.active_i != -1 && // exists active block
    this.active_i != 0 && // not on left side
    this.grid[this.active_i-1][this.active_j] == null) { // no left neighbor
      this.grid[this.active_i-1][this.active_j] = this.grid[this.active_i][this.active_j];
      /////// this.grid[this.active_i][this.active_j].left();
      this.grid[this.active_i][this.active_j] = null;
      this.active_i--;
      this.grid[this.active_i][this.active_j].x = this.x + (GridSize * active_i);
      this.grid[this.active_i][this.active_j].y = this.y + (GridSize * active_j);
    }
  }

  void active_right() {
    if (this.active_i != -1 && // exists active block
    this.active_i != this.width-1 && // not on right side
    this.grid[this.active_i+1][this.active_j] == null) { // no left neighbor
      this.grid[this.active_i+1][this.active_j] = this.grid[this.active_i][this.active_j];
      /////// this.grid[this.active_i][this.active_j].left();
      this.grid[this.active_i][this.active_j] = null;
      this.active_i++;
      this.grid[this.active_i][this.active_j].x = this.x + (GridSize * active_i);
      this.grid[this.active_i][this.active_j].y = this.y + (GridSize * active_j);
    }
  }

  void active_step_down() {
    if (this.active_i != -1 && // exists active block
    this.active_j < this.height-1 && // not on bottom of grid
    this.grid[this.active_i][this.active_j+1] == null) { // no lower neighbor
      ///// this.grid[this.active_i][this.active_j].step_down() play animation
      this.grid[this.active_i][this.active_j+1] = this.grid[this.active_i][this.active_j];
      this.grid[this.active_i][this.active_j] = null;
      this.active_j++;
      this.grid[this.active_i][this.active_j].x = this.x + (GridSize * active_i);
      this.grid[this.active_i][this.active_j].y = this.y + (GridSize * active_j);
    }
    if (this.active_j == this.height-1 ||  // active block now on bottom
    this.grid[this.active_i][this.active_j+1] != null) { // or on other block
      this.active_i = -1;  // kill block
      this.check_words();
    }
  }

  void active_drop() {
    while (this.active_i != -1 && // exists active block
    this.active_j < this.height-1 && // not on bottom of grid
    this.grid[this.active_i][this.active_j+1] == null) { // no lower neighbor
      active_step_down();
    }
    this.active_i = -1;
    this.check_words();
  }

  void next_block() {
    Block b;
    // put test words here
    b = new Block();
    b.letter = pick_text();
    this.active_i = this.spawn_x; 
    this.active_j = 0;
    b.x = this.x + (GridSize * active_i);
    b.y = this.y + (GridSize * active_j);
    if (this.grid[this.spawn_x][0] != null) {
      status = status.GAME_OVER;
      return;
    }
    this.grid[this.spawn_x][0] = b;
  }

  void update() {
    for (int i = 0; i < this.width; i++) {
      for (int j = 0; j < this.height; j++) {
        if (this.grid[i][j] != null) {
          this.grid[i][j].x = this.x + (GridSize * i);
          this.grid[i][j].y = this.y + (GridSize * j);
          this.grid[i][j].falling_speed = 0;
        }
      }
    }
    if (this.active_i != -1) { // exists active block
      this.active_step_down();
    } else {
      this.next_block();
    }
    this.ghosts.clear();
  }

  void make_blocks_fall_if_loose() {
    for (int i = 0; i < this.width; i++) {
      for (int j = 0; j < this.height; j++) {
        if (this.grid[i][j] != null) {
          this.grid[i][j].fall_if_loose();
        }
      }
    }
    for (Block b : this.ghosts) {
      b.fall_if_loose();
    }
  }

  void check_words() {
    int word_length;
    int i, j, start_i, start_j, delete_j;
    String[] letters;
    String word;
    for (word_length = 4; word_length>=4; word_length--) {
      // horizontal words 
      for (start_i=0; start_i<=this.width-word_length; start_i++) {
        for (j=0; j<this.height; j++) {
          letters = new String[0];
          for (i=start_i; i<start_i+word_length; i++) {
            if (this.grid[i][j] != null) {
              letters = append(letters, this.grid[i][j].letter);
            } else {
              letters = new String[0];
              break;
            }
          }
          word = join(letters, "");
          if (boolean(words.get(word))) {
            for (i=start_i; i<start_i+word_length; i++) {
              this.grid[i][j].become_ghost();
              this.ghosts.add(this.grid[i][j]);
              this.grid[i][j] = null;
              for (delete_j=j; delete_j>0; delete_j--) {
                if (this.grid[i][delete_j-1] != null) {
                  this.grid[i][delete_j-1].falling_speed = 1; // make it fall physically
                }
                this.grid[i][delete_j] = this.grid[i][delete_j-1]; // & theoretically
              }
              this.grid[i][0] = null;
            }
            increment_points(word);
            println(word);
            complete_words.add(Margin + GridSize*start_i + round(GridSize*word_length/2), 
            Margin + GridSize*j + round(GridSize/2), 
            word);
            this.check_words();
            return;
          }
        }
      }
    }
    // vertical words
    for (word_length = 4; word_length>=4; word_length--) {
      for (start_j=0; start_j<=this.height-word_length; start_j++) {
        for (i=0; i<this.width; i++) {
          letters = new String[0];
          for (j=start_j; j<start_j+word_length; j++) {
            if (this.grid[i][j] != null) {
              letters = append(letters, this.grid[i][j].letter);
            } else {
              letters = new String[0];
              break;
            }
          }
          word = join(letters, "");
          if (boolean(words.get(word))) {
            for (j=start_j; j<start_j+word_length; j++) {
              this.grid[i][j].become_ghost();
              this.ghosts.add(this.grid[i][j]);
              this.grid[i][j] = null;
            }
            for (j=start_j+word_length-1; j>=word_length; j--) {
              if (this.grid[i][j-word_length] != null) {
                this.grid[i][j-word_length].falling_speed = 1;
              }
              this.grid[i][j] = this.grid[i][j-word_length];
            }
            this.grid[i][0] = null;
            increment_points(word);
            println(word);
            complete_words.add(Margin + GridSize*i + round(GridSize/2), 
            Margin + GridSize*start_j + round(GridSize*word_length/2), 
            word);
            this.check_words();
            return;
          }
        }
      }
    } // end word_length
  }

  void draw() {
    if (this.grid == null) {
      return;
    }
    image(body_img, this.x-5, this.y-5, (this.width*GridSize)+10, (this.height*GridSize)+10);
    for (Block b : this.ghosts) {
      b.draw();
    }
    for (int i = 0; i < this.width; i++) {
      for (int j = 0; j < this.height; j++) {
        if (this.grid[i][j] != null) {
          this.grid[i][j].draw();
        }
      }
    }
  }
}

class Block {
  float x, y;
  String letter;
  color klr = color(220, 250, 255);
  color text_klr = TextColor;
  int falling_speed = 0;
  boolean is_ghost = false;

  void draw() {
    fill(klr);
    noStroke();
    rect(this.x, this.y, GridSize, GridSize);
    textAlign(CENTER, CENTER);
    textSize(int(GridSize*0.6));
    fill(this.text_klr);
    text(this.letter, this.x+round(GridSize/2), this.y+round(GridSize*0.45));
  }

  void become_ghost() {
    this.is_ghost = true;
    this.klr = color(0);
    this.text_klr = GhostlyTextColor;
  }

  void fall_if_loose() {
    this.y += GridSize*this.falling_speed/frameRate;
    if (this.is_ghost) {
      this.klr = color(1, 1, 1, int(alpha(this.klr)*0.95));
      this.text_klr = color(red(this.text_klr), green(this.text_klr), blue(this.text_klr), int(alpha(this.text_klr)*0.96));
    }
  }
}

class Bubble {
  int x=0, y=0;
  boolean vertical = false;  // unused
  String text = "bear";
  int length = 4;  // unused
  int rest_x, rest_y;
  int v_x, v_y;

  Bubble(int x, int y, int rest_x, int rest_y, String word) {
    this.x = x;
    this.y = y;
    this.rest_x = rest_x;
    this.rest_y = rest_y;
    this.v_x = int(random(-4, 5));
    this.v_y = int(random(-3, 7));
    this.text = word;
  }

  void update() {
    if (abs(this.x-this.rest_x)+abs(this.y-this.rest_y)>3) {
      this.x += this.v_x;
      this.y += this.v_y;
      this.x = int(this.x*0.9 + this.rest_x*0.1);
      this.y = int(this.y*0.9 + this.rest_y*0.1);
      this.v_x += int((this.rest_x - this.x)*0.05);
      this.v_y += int((this.rest_y - this.y)*0.05);
    }
  }

  void draw() {
    image(bubble_img, this.x, this.y-int(GridSize*0.6), int(GridSize*2.8), int(GridSize*1.7));
    fill(230, 255, 0);
    textAlign(CENTER, CENTER);
    textSize(int(GridSize*0.55));
    text(this.text, this.x+round(GridSize*1.45), this.y+round(GridSize*0.15));
  }
}

class WordList {
  int height, number_of_words;
  Bubble[] bubbles;
  int x, y;

  WordList(int x, int y, int n) {
    this.x = x;
    this.y = y;
    this.height = n;
    this.number_of_words = int(n*0.7); // stored word bubbles are spaced wider than every gridsize
    this.bubbles = new Bubble[number_of_words];
  }

  void update() {
    for (Bubble b : this.bubbles) {
      if (b != null) {
        b.update();
      }
    }
  }

  void draw() {
    fill(0, 0, 255);
    for (int i = this.number_of_words-1; i>=0; i--) {
      if (this.bubbles[i] != null) {
        this.bubbles[i].draw();
      }
    }
  }

  void add(int x, int y, String word) {
    for (int i = this.number_of_words-1; i >= 1; i--) {
      this.bubbles[i] = this.bubbles[i-1];
      if (this.bubbles[i] != null) {
        this.bubbles[i].rest_y = this.y+(int(GridSize*(this.height-(i*1.5)-1)));
      }
    }
    bubbles[0] = new Bubble(x, y, this.x, this.y+GridSize*(this.height-1), word);
  }
}

void draw_points() {
  fill(40, 200, 0);
  textAlign(RIGHT, BOTTOM);
  textSize(int(GridSize*0.35));
  text(str(points), (GridWidth*GridSize)+Margin, Margin-6);
}

void draw_preview() {
  fill(40, 200, 0);
  textAlign(LEFT, BOTTOM);
  textSize(int(GridSize*0.4));
  text(preview, Margin, Margin-10);
}

void draw_quit_button() {
  fill(40, 200, 0);
  textAlign(RIGHT, TOP);
  textSize(int(GridSize*0.3));
  text("stop", width-5, 5);
}

void draw_game_over() {
  fill(255, 60, 0);
  textAlign(CENTER, CENTER);
  textSize(int(GridSize*1.5));
  text("Game Over", round(width/2), round(height/3));
}

void draw_menu() {
  image(background_img, 0, 0, width, height);
  fill(0, 200, 200, 100);
  rect(0, 0, width, height);
  Block b;
  String title = "bear";
  for (int i=0; i<title.length (); i++) {
    b = new Block();
    b.x = 50  + GridSize*i;
    b.y = 100;
    b.letter = str(title.charAt(i));
    b.draw();
  }
  title = "words";
  for (int i=0; i<title.length (); i++) {
    b = new Block();
    b.x = 50 + GridSize  + GridSize*i;
    b.y = 100 + GridSize*2;
    b.letter = str(title.charAt(i));
    b.draw();
  }
  fill(255, 255, 255);
  textSize(int(GridSize*0.3));
  text("Bear Words\nby Isaac Reilly\nisaac.g.reilly@gmail.com\n(2014.12.26)\nfor the Spirit Bear Game Jam\nbuilt-in keys:\nmove left   move right   drop\n          LEFT   RIGHT          DOWN\nA      F    D\nJ       ;    K\n       A       '    SPACE\nOr click on the side of the window you want to go toward\nPress any key to start\nX and Q quit game\n\nWords must be\nexactly four letters long", 115, 200, 250, 600);
}

void increment_points(String s) {
  points += int(pow(3, s.length()-4));
}

String pick_text() {
  if (CHEAT_MODE) {
    if (random(1) > 0.5) {
      return("x");
    } else {
      return("o");
    }
  }
  String return_value = preview;

  if (letter_buffer.size() == 0) {
    String word = word_list[int(random(word_list.length))];
    for (int i=0; i<word.length (); i++) {
      letter_buffer.append(str(word.charAt(i)));
    }
    letter_buffer.shuffle();
  }
  preview = letter_buffer.remove(0);
  return(return_value);
}

