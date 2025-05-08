
/* TEST APPS 3: LATTICE
   Assumes running on 4 ranks, resident task on rank 2
   Should produce something like:
   "#FCFFDD, #FCFFDD, #26185F"
 */

import io;
import location;
import R;

trace(
  R("library(lattice)",
    "toString(level.colors(c(1,2,3), c(1,2,3)))")
      );
