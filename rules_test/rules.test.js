// Firestore 보안 규칙 테스트. 에뮬레이터에서 실행한다:
//   cd rules_test && npm install && npm test
//
// 앱(lib/data/firestore_backend.dart)이 실제로 보내는 쓰기/쿼리 형태를 그대로 따라 한다.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-awake',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

const db = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

/** 앱의 createTeam과 같은 묶음 쓰기. */
function createTeam(fs, uid, teamId = 'team1', code = 'CODE2345') {
  const batch = writeBatch(fs);
  batch.set(doc(fs, `teams/${teamId}`), {
    name: '청년부',
    ownerId: uid,
    inviteCode: code,
  });
  batch.set(doc(fs, `teams/${teamId}/members/${uid}`), {
    teamName: '청년부',
    uid,
    displayName: uid,
    role: 'leader',
  });
  batch.set(doc(fs, `invites/${code}`), {
    teamId,
    teamName: '청년부',
    createdBy: uid,
  });
  return batch.commit();
}

/** 앱의 joinTeam과 같은 쓰기. */
function join(fs, uid, { teamId = 'team1', code = 'CODE2345', role = 'member' } = {}) {
  return setDoc(doc(fs, `teams/${teamId}/members/${uid}`), {
    teamName: '청년부',
    uid,
    displayName: uid,
    role,
    inviteCode: code,
  });
}

/** 규칙을 건너뛰고 미리 데이터를 넣는다. */
async function seed(fn) {
  await env.withSecurityRulesDisabled((ctx) => fn(ctx.firestore()));
}

/** leader가 만든 team1에 member/editor가 있는 상태. */
async function seedTeam() {
  await seed(async (fs) => {
    await setDoc(doc(fs, 'teams/team1'), {
      name: '청년부',
      ownerId: 'leader',
      inviteCode: 'CODE2345',
    });
    await setDoc(doc(fs, 'invites/CODE2345'), {
      teamId: 'team1',
      teamName: '청년부',
      createdBy: 'leader',
    });
    for (const [uid, role] of [
      ['leader', 'leader'],
      ['editor', 'editor'],
      ['member', 'member'],
    ]) {
      await setDoc(doc(fs, `teams/team1/members/${uid}`), {
        teamName: '청년부',
        uid,
        displayName: uid,
        role,
      });
    }
  });
}

describe('팀 만들기', () => {
  test('팀, 리더 멤버, 초대 코드를 한 번에 만들 수 있다', async () => {
    await assertSucceeds(createTeam(db('alice'), 'alice'));
  });

  test('로그인하지 않으면 만들 수 없다', async () => {
    await assertFails(createTeam(anon(), 'alice'));
  });

  test('다른 사람을 주인으로 적을 수 없다', async () => {
    const fs = db('alice');
    const batch = writeBatch(fs);
    batch.set(doc(fs, 'teams/t'), { name: 'x', ownerId: 'bob' });
    batch.set(doc(fs, 'teams/t/members/alice'), {
      teamName: 'x',
      uid: 'alice',
      displayName: 'a',
      role: 'leader',
    });
    await assertFails(batch.commit());
  });

  test('리더 멤버 문서 없이 팀만 만들 수 없다', async () => {
    const fs = db('alice');
    await assertFails(setDoc(doc(fs, 'teams/t'), { name: 'x', ownerId: 'alice' }));
  });

  test('이미 있는 팀에 자신을 리더로 넣을 수 없다', async () => {
    await seedTeam();
    const fs = db('mallory');
    await assertFails(
      setDoc(doc(fs, 'teams/team1/members/mallory'), {
        teamName: '청년부',
        uid: 'mallory',
        displayName: 'm',
        role: 'leader',
      }),
    );
  });

  test('남의 팀을 가리키는 초대 코드를 만들 수 없다', async () => {
    await seedTeam();
    await assertFails(
      setDoc(doc(db('mallory'), 'invites/EVIL2345'), {
        teamId: 'team1',
        teamName: '청년부',
        createdBy: 'mallory',
      }),
    );
  });
});

describe('초대 코드로 참여', () => {
  beforeEach(seedTeam);

  test('코드를 알면 초대 문서를 읽을 수 있다', async () => {
    await assertSucceeds(getDoc(doc(db('newbie'), 'invites/CODE2345')));
  });

  test('초대 코드 목록은 볼 수 없다', async () => {
    await assertFails(getDocs(collection(db('newbie'), 'invites')));
  });

  test('올바른 코드로 멤버로 참여한다', async () => {
    const fs = db('newbie');
    // 앱은 먼저 자기 멤버 문서가 있는지 확인한다.
    await assertSucceeds(getDoc(doc(fs, 'teams/team1/members/newbie')));
    await assertSucceeds(join(fs, 'newbie'));
  });

  test('틀린 코드로는 참여할 수 없다', async () => {
    await assertFails(join(db('newbie'), 'newbie', { code: 'WRONG234' }));
  });

  test('참여하면서 편집자나 리더가 될 수 없다', async () => {
    await assertFails(join(db('newbie'), 'newbie', { role: 'editor' }));
    await assertFails(join(db('newbie'), 'newbie', { role: 'leader' }));
  });

  test('다른 사람을 대신 참여시킬 수 없다', async () => {
    const fs = db('newbie');
    await assertFails(
      setDoc(doc(fs, 'teams/team1/members/someone'), {
        teamName: '청년부',
        uid: 'someone',
        displayName: 's',
        role: 'member',
        inviteCode: 'CODE2345',
      }),
    );
  });

  test('리더는 초대 코드를 새로 만들 수 있다', async () => {
    const fs = db('leader');
    const batch = writeBatch(fs);
    batch.set(doc(fs, 'invites/NEW23456'), {
      teamId: 'team1',
      teamName: '청년부',
      createdBy: 'leader',
    });
    batch.update(doc(fs, 'teams/team1'), { inviteCode: 'NEW23456' });
    batch.delete(doc(fs, 'invites/CODE2345'));
    await assertSucceeds(batch.commit());
  });

  test('멤버는 초대 코드를 바꾸거나 지울 수 없다', async () => {
    const fs = db('member');
    await assertFails(updateDoc(doc(fs, 'teams/team1'), { inviteCode: 'X' }));
    await assertFails(deleteDoc(doc(fs, 'invites/CODE2345')));
  });
});

describe('팀 읽기와 내 팀 목록', () => {
  beforeEach(seedTeam);

  test('팀원은 팀과 멤버 목록을 읽는다', async () => {
    const fs = db('member');
    await assertSucceeds(getDoc(doc(fs, 'teams/team1')));
    await assertSucceeds(getDocs(collection(fs, 'teams/team1/members')));
  });

  test('팀원이 아니면 팀을 읽을 수 없다', async () => {
    const fs = db('stranger');
    await assertFails(getDoc(doc(fs, 'teams/team1')));
    await assertFails(getDocs(collection(fs, 'teams/team1/members')));
    await assertFails(getDocs(collection(fs, 'teams/team1/songs')));
  });

  test('내 멤버 문서만 컬렉션 그룹으로 조회할 수 있다', async () => {
    const fs = db('member');
    await assertSucceeds(
      getDocs(query(collectionGroup(fs, 'members'), where('uid', '==', 'member'))),
    );
    await assertFails(
      getDocs(query(collectionGroup(fs, 'members'), where('uid', '==', 'leader'))),
    );
  });
});

describe('역할', () => {
  beforeEach(seedTeam);

  test('리더는 다른 사람의 역할을 바꾼다', async () => {
    await assertSucceeds(
      updateDoc(doc(db('leader'), 'teams/team1/members/member'), { role: 'editor' }),
    );
  });

  test('리더도 자기 역할은 바꿀 수 없다 (리더가 없어지는 것 방지)', async () => {
    await assertFails(
      updateDoc(doc(db('leader'), 'teams/team1/members/leader'), { role: 'member' }),
    );
  });

  test('멤버나 편집자는 역할을 바꿀 수 없다', async () => {
    await assertFails(
      updateDoc(doc(db('member'), 'teams/team1/members/member'), { role: 'leader' }),
    );
    await assertFails(
      updateDoc(doc(db('editor'), 'teams/team1/members/member'), { role: 'editor' }),
    );
  });

  test('없는 역할 이름은 쓸 수 없다', async () => {
    await assertFails(
      updateDoc(doc(db('leader'), 'teams/team1/members/member'), { role: 'admin' }),
    );
  });

  test('멤버는 스스로 나갈 수 있고, 리더는 내보낼 수 있다', async () => {
    await assertSucceeds(deleteDoc(doc(db('member'), 'teams/team1/members/member')));
    await assertSucceeds(deleteDoc(doc(db('leader'), 'teams/team1/members/editor')));
  });

  test('팀 주인은 나갈 수 없고, 멤버는 남을 내보낼 수 없다', async () => {
    await assertFails(deleteDoc(doc(db('leader'), 'teams/team1/members/leader')));
    await assertFails(deleteDoc(doc(db('member'), 'teams/team1/members/editor')));
  });
});

describe('곡과 콘티', () => {
  beforeEach(seedTeam);

  for (const col of ['songs', 'setlists']) {
    test(`${col}: 편집자와 리더는 쓰고, 멤버는 읽기만`, async () => {
      const data = { title: 'x' };
      await assertSucceeds(setDoc(doc(db('editor'), `teams/team1/${col}/a`), data));
      await assertSucceeds(setDoc(doc(db('leader'), `teams/team1/${col}/b`), data));
      await assertFails(setDoc(doc(db('member'), `teams/team1/${col}/c`), data));
      await assertSucceeds(getDocs(collection(db('member'), `teams/team1/${col}`)));
      await assertFails(deleteDoc(doc(db('member'), `teams/team1/${col}/a`)));
    });
  }
});

describe('주석', () => {
  const path = 'teams/team1/scores/s1/annotations';
  const note = (authorId, visibility) => ({
    type: 'ink',
    authorId,
    visibility,
    page: 0,
    color: 0,
    strokes: [],
    width: 0.004,
  });

  beforeEach(async () => {
    await seedTeam();
    await seed(async (fs) => {
      await setDoc(doc(fs, `${path}/shared`), note('editor', 'team'));
      await setDoc(doc(fs, `${path}/secret`), note('editor', 'private'));
    });
  });

  test('팀 공유 주석은 모두, 개인 주석은 작성자만 읽는다', async () => {
    await assertSucceeds(getDoc(doc(db('member'), `${path}/shared`)));
    await assertFails(getDoc(doc(db('member'), `${path}/secret`)));
    await assertSucceeds(getDoc(doc(db('editor'), `${path}/secret`)));
  });

  test('앱이 쓰는 두 쿼리 (팀 공유 / 내 개인)는 통과한다', async () => {
    const fs = db('member');
    await assertSucceeds(
      getDocs(query(collection(fs, path), where('visibility', '==', 'team'))),
    );
    await assertSucceeds(
      getDocs(
        query(
          collection(fs, path),
          where('authorId', '==', 'member'),
          where('visibility', '==', 'private'),
        ),
      ),
    );
    // 조건 없이 전체를 읽으려 하면 거부된다.
    await assertFails(getDocs(collection(fs, path)));
  });

  test('멤버도 자기 주석은 만들고, 남의 이름으로는 만들 수 없다', async () => {
    const fs = db('member');
    await assertSucceeds(setDoc(doc(fs, `${path}/m1`), note('member', 'private')));
    await assertFails(setDoc(doc(fs, `${path}/m2`), note('editor', 'team')));
    await assertFails(
      setDoc(doc(fs, `${path}/m3`), { ...note('member', 'team'), type: 'video' }),
    );
  });

  test('남의 주석은 고칠 수 없고, 팀 공유 주석은 편집자가 지울 수 있다', async () => {
    await assertFails(updateDoc(doc(db('member'), `${path}/shared`), { page: 1 }));
    await assertFails(deleteDoc(doc(db('member'), `${path}/shared`)));
    await assertSucceeds(deleteDoc(doc(db('leader'), `${path}/shared`)));
    await assertFails(deleteDoc(doc(db('leader'), `${path}/secret`)));
  });
});
