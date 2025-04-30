
/* TEST APPS 2: GRAPHICS: FARVER
   Assumes running on 4 ranks, resident task on rank 2
 */

import io;
import location;
import R;

trace(
  R("library(farver)",
    "toString(decode_colour(rainbow(10)))")
      );
