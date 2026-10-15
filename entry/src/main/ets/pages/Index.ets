/**
 * 学习记忆卡片制作台（ArkTS / HarmonyOS PC 端）
 * ------------------------------------------------------------
 * 布局：左侧深绿导航栏【录入台 / 卡片库 / 复习】+ 右侧内容区（PC 分模块布局）
 *
 * 录入台：左栏批量录入（每行：题干 | 答案 #标签1 #标签2，支持全角｜），
 *         右栏实时解析预览（题目/答案/标签），一键导入 + 查重 + 示例填充
 * 卡片库：关键词搜索（题干/答案/标签）+ 标签筛选 + 行内编辑 + 删除 + 掌握度标记
 * 复习页：3D 翻卡（正面题目/背面答案）、上一张/下一张、按掌握度筛选、洗牌乱序、
 *         认识度三档标记（陌生/模糊/已掌握）并自动同步统计
 * 持久化：Preferences 本地存储，重启/刷新不丢失（预览器自动降级为内存模式）
 *
 * 适配：DevEco Studio 5.0+（API 12+），无第三方依赖
 */
import { preferences } from '@kit.ArkData'

// ===================== 数据模型 =====================
class CardItem {
  id: number
  question: string
  answer: string
  tags: string[]
  mastery: number // 0 陌生 / 1 模糊 / 2 已掌握

  constructor(id: number, question: string, answer: string, tags: string[], mastery: number) {
    this.id = id
    this.question = question
    this.answer = answer
    this.tags = tags
    this.mastery = mastery
  }
}

// 解析结果（批量录入预览用）
class ParseResult {
  cards: CardItem[] = []
  skip: number = 0
}

// ===================== 主题配色（简洁校园风） =====================
const COLOR_SIDEBAR: string = '#2E5C4D'      // 侧边栏深绿
const COLOR_SIDEBAR_ACTIVE: string = '#3E7A66' // 导航选中
const COLOR_BG: string = '#F7F4EC'           // 内容区米白
const COLOR_PRIMARY: string = '#3FA372'      // 主绿
const COLOR_SUB: string = '#8A8A8A'          // 次要文字
const COLOR_INPUT_BG: string = '#F5F0E4'     // 输入框底
const COLOR_FRONT: string = '#3D7A63'        // 卡片正面：黑板绿
const COLOR_BACK: string = '#FFF3B8'         // 卡片背面：便利贴黄
const COLOR_BACK_TEXT: string = '#5A4A1E'
const COLOR_TAG_BG: string = '#E3F2E8'       // 标签底色
const COLOR_TAG_FG: string = '#2E7D5B'       // 标签文字

@Entry
@Component
struct Index {
  // ---------- 导航 ----------
  @State navIndex: number = 0 // 0 录入台 / 1 卡片库 / 2 复习
  // ---------- 全部卡片 ----------
  @State cards: CardItem[] = []
  // ---------- 录入台 ----------
  @State inputText: string = ''
  @State draft: CardItem[] = []
  @State draftSkip: number = 0
  // ---------- 卡片库 ----------
  @State searchKw: string = ''
  @State activeTag: string = '' // '' 表示全部
  @State editingId: number = -1
  @State editQ: string = ''
  @State editA: string = ''
  @State editTags: string = ''
  // ---------- 复习 ----------
  @State reviewFilter: string = 'all' // all / todo / done
  @State shuffled: boolean = false
  @State shuffleOrder: number[] = []
  @State curIndex: number = 0
  @State showFront: boolean = true
  @State flipAngle: number = 0
  @State flipping: boolean = false

  private pref: preferences.Preferences | null = null
  private nextId: number = 1
  private flipGen: number = 0

  // ===================== 生命周期 =====================
  aboutToAppear(): void {
    try {
      const ctx = getContext(this)
      preferences.getPreferences(ctx, 'memory_cards').then((p: preferences.Preferences) => {
        this.pref = p
        const seeded: boolean = p.getSync('mc2_seeded', false) as boolean
        if (!seeded) {
          this.cards = this.buildSeedCards()
          p.putSync('mc2_seeded', true)
          this.saveCards()
        } else {
          this.loadCards()
        }
      }).catch(() => {
      })
    } catch (e) {
      // 预览器等环境不支持持久化时自动降级为内存模式
    }
  }

  private buildSeedCards(): CardItem[] {
    const list: CardItem[] = []
    list.push(new CardItem(this.nextId++, '牛顿第一定律说了什么？',
      '一切物体总保持静止状态或匀速直线运动状态，直到有外力迫使它改变这种状态为止。', ['物理', '定律'], 0))
    list.push(new CardItem(this.nextId++, '勾股定理的内容是什么？',
      '直角三角形中，斜边的平方等于两条直角边的平方之和，即 a² + b² = c²。', ['数学', '公式'], 2))
    list.push(new CardItem(this.nextId++, '水的化学式是什么？',
      'H₂O，由两个氢原子和一个氧原子组成。', ['化学'], 1))
    list.push(new CardItem(this.nextId++, '"abandon" 是什么意思？',
      '动词：放弃、抛弃、遗弃。例：不要轻易 abandon 你的学业。', ['英语', '词汇'], 0))
    list.push(new CardItem(this.nextId++, '唐代被称为"诗鬼"的诗人是谁？',
      '李贺。其诗风奇诡冷艳，代表作有《雁门太守行》等。', ['文学', '常识'], 0))
    return list
  }

  // ===================== 持久化 =====================
  private saveCards(): void {
    const p: preferences.Preferences | null = this.pref
    if (p === null) {
      return
    }
    try {
      p.putSync('count', this.cards.length)
      for (let i = 0; i < this.cards.length; i++) {
        const c: CardItem = this.cards[i]
        p.putSync('q' + i.toString(), c.question)
        p.putSync('a' + i.toString(), c.answer)
        p.putSync('t' + i.toString(), c.tags.join(','))
        p.putSync('m' + i.toString(), c.mastery)
      }
      p.flush()
    } catch (e) {
    }
  }

  private loadCards(): void {
    const p: preferences.Preferences | null = this.pref
    if (p === null) {
      return
    }
    try {
      const count: number = p.getSync('count', 0) as number
      const list: CardItem[] = []
      for (let i = 0; i < count; i++) {
        const q: string = p.getSync('q' + i.toString(), '') as string
        const a: string = p.getSync('a' + i.toString(), '') as string
        const t: string = p.getSync('t' + i.toString(), '') as string
        const m: number = p.getSync('m' + i.toString(), 0) as number
        if (q !== '') {
          const tags: string[] = []
          const parts: string[] = t.split(',')
          for (const raw of parts) {
            const name: string = raw.trim()
            if (name !== '' && !tags.includes(name)) {
              tags.push(name)
            }
          }
          list.push(new CardItem(this.nextId++, q, a, tags, m))
        }
      }
      this.cards = list
    } catch (e) {
    }
  }

  // ===================== 批量文本解析 =====================
  // 每行：题干 | 答案 #标签1 #标签2（支持全角｜，标签可出现在行内任意位置）
  private parseLine(line: string): CardItem | null {
    let s: string = line.trim()
    if (s === '') {
      return null
    }
    s = s.replace(/｜/g, '|')
    // 抽取 #标签
    const tags: string[] = []
    const matches: RegExpMatchArray | null = s.match(/#[^\s#|]+/g)
    if (matches !== null) {
      for (const t of matches) {
        const name: string = t.substring(1)
        if (name !== '' && !tags.includes(name)) {
          tags.push(name)
        }
      }
    }
    s = s.replace(/#[^\s#|]+/g, ' ').trim()
    const parts: string[] = s.split('|')
    const q: string = parts[0].trim()
    const a: string = parts.length > 1 ? parts.slice(1).join('|').trim() : ''
    if (q === '' || a === '') {
      return null
    }
    return new CardItem(0, q, a, tags, 0)
  }

  private refreshDraft(): void {
    const res: ParseResult = new ParseResult()
    const lines: string[] = this.inputText.split('\n')
    for (const line of lines) {
      const c: CardItem | null = this.parseLine(line)
      if (c === null) {
        if (line.trim() !== '') {
          res.skip++
        }
      } else {
        res.cards.push(c)
      }
    }
    this.draft = res.cards
    this.draftSkip = res.skip
  }

  private importDraft(): void {
    if (this.draft.length === 0) {
      this.toast('没有可导入的卡片，请检查格式 📝')
      return
    }
    let imported: number = 0
    let dup: number = 0
    for (const c of this.draft) {
      const exists: boolean = this.cards.some((item: CardItem) => item.question === c.question)
      if (exists) {
        dup++
      } else {
        this.cards.push(new CardItem(this.nextId++, c.question, c.answer, c.tags, 0))
        imported++
      }
    }
    this.saveCards()
    this.inputText = ''
    this.draft = []
    this.draftSkip = 0
    let msg: string = '成功导入 ' + imported.toString() + ' 张卡片 🎉'
    if (dup > 0) {
      msg += '，跳过重复 ' + dup.toString() + ' 张'
    }
    this.toast(msg)
  }

  private fillSample(): void {
    this.inputText = '牛顿第二定律的表达式？| F = ma，加速度与合外力成正比、与质量成反比。 #物理 #公式\n' +
      '光合作用的场所是？| 叶绿体（类囊体薄膜发生光反应，基质发生暗反应）。 #生物\n' +
      '"call off" 是什么意思？| 取消，中止。例：The meeting was called off. #英语 #词汇\n' +
      '这首诗缺答案 #会被跳过'
    this.refreshDraft()
  }

  private clearInput(): void {
    this.inputText = ''
    this.draft = []
    this.draftSkip = 0
  }

  // ===================== 卡片库逻辑 =====================
  private allTags(): string[] {
    const tags: string[] = []
    for (const c of this.cards) {
      for (const t of c.tags) {
        if (!tags.includes(t)) {
          tags.push(t)
        }
      }
    }
    return tags
  }

  private filteredLibrary(): CardItem[] {
    const kw: string = this.searchKw.trim().toLowerCase()
    return this.cards.filter((c: CardItem) => {
      if (this.activeTag !== '' && !c.tags.includes(this.activeTag)) {
        return false
      }
      if (kw === '') {
        return true
      }
      const hitTag: boolean = c.tags.some((t: string) => t.toLowerCase().includes(kw))
      return c.question.toLowerCase().includes(kw) || c.answer.toLowerCase().includes(kw) || hitTag
    })
  }

  private startEdit(card: CardItem): void {
    this.editingId = card.id
    this.editQ = card.question
    this.editA = card.answer
    this.editTags = card.tags.join(' ')
  }

  private saveEdit(): void {
    const q: string = this.editQ.trim()
    const a: string = this.editA.trim()
    if (q === '' || a === '') {
      this.toast('题目和答案不能为空 ✍️')
      return
    }
    const tags: string[] = []
    const raws: string[] = this.editTags.split(/[\s,，]+/)
    for (const raw of raws) {
      let t: string = raw.trim()
      if (t === '') {
        continue
      }
      if (t.startsWith('#')) {
        t = t.substring(1)
      }
      if (t !== '' && !tags.includes(t)) {
        tags.push(t)
      }
    }
    for (const c of this.cards) {
      if (c.id === this.editingId) {
        c.question = q
        c.answer = a
        c.tags = tags
        break
      }
    }
    this.cards = this.cards.slice()
    this.saveCards()
    this.editingId = -1
    this.toast('卡片已更新 ✅')
  }

  private removeCard(id: number): void {
    const idx: number = this.cards.findIndex((c: CardItem) => c.id === id)
    if (idx >= 0) {
      this.cards.splice(idx, 1)
      this.saveCards()
      this.toast('已删除卡片 🗑')
    }
  }

  // ===================== 复习逻辑 =====================
  private reviewList(): CardItem[] {
    const list: CardItem[] = this.cards.filter((c: CardItem) => {
      if (this.reviewFilter === 'todo') {
        return c.mastery < 2
      }
      if (this.reviewFilter === 'done') {
        return c.mastery === 2
      }
      return true
    })
    if (this.shuffled && this.shuffleOrder.length > 0) {
      list.sort((a: CardItem, b: CardItem) => this.orderPos(a.id) - this.orderPos(b.id))
    }
    return list
  }

  private orderPos(id: number): number {
    const i: number = this.shuffleOrder.indexOf(id)
    return i === -1 ? 999999 : i
  }

  private toggleShuffle(): void {
    this.shuffled = !this.shuffled
    if (this.shuffled) {
      const ids: number[] = []
      for (const c of this.cards) {
        ids.push(c.id)
      }
      // Fisher-Yates 洗牌
      for (let i = ids.length - 1; i > 0; i--) {
        const j: number = Math.floor(Math.random() * (i + 1))
        const tmp: number = ids[i]
        ids[i] = ids[j]
        ids[j] = tmp
      }
      this.shuffleOrder = ids
      this.toast('已开启乱序模式 🔀')
    } else {
      this.shuffleOrder = []
    }
    this.resetFlip()
  }

  private curPos(len: number): number {
    if (len === 0) {
      return 0
    }
    let i: number = this.curIndex % len
    if (i < 0) {
      i += len
    }
    return i
  }

  private changeCard(step: number): void {
    this.curIndex += step
    this.resetFlip()
  }

  // 标记掌握度：0 陌生 / 1 模糊 / 2 已掌握
  private mark(mastery: number): void {
    const list: CardItem[] = this.reviewList()
    if (list.length === 0) {
      return
    }
    const card: CardItem = list[this.curPos(list.length)]
    for (const c of this.cards) {
      if (c.id === card.id) {
        c.mastery = mastery
        break
      }
    }
    this.cards = this.cards.slice()
    this.saveCards()
    this.curIndex++ // 自动切到下一张（渲染时自动取模回绕）
    const names: string[] = ['已标记：陌生 💪', '已标记：模糊 🤔', '太棒了，已掌握！🎉']
    this.toast(names[mastery])
  }

  private resetFlip(): void {
    this.flipGen++
    this.showFront = true
    this.flipAngle = 0
    this.flipping = false
  }

  // 点击翻转：90° 侧立（不可见）时安全切换正反面
  private flipCard(): void {
    if (this.flipping) {
      return
    }
    this.flipping = true
    const gen: number = ++this.flipGen
    this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseIn }, () => {
      this.flipAngle += 90
    })
    setTimeout(() => {
      if (gen !== this.flipGen) {
        return
      }
      this.showFront = !this.showFront
      this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
        this.flipAngle += 90
      })
      setTimeout(() => {
        if (gen !== this.flipGen) {
          return
        }
        this.flipping = false
      }, 240)
    }, 230)
  }

  // ===================== 通用 =====================
  private toast(msg: string): void {
    this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1600 })
  }

  private doneCount(): number {
    return this.cards.filter((c: CardItem) => c.mastery === 2).length
  }

  // ===================== UI：侧边栏 =====================
  @Builder
  NavItem(icon: string, title: string, desc: string, index: number) {
    Row({ space: 10 }) {
      Text(icon).fontSize(19)
      Column({ space: 2 }) {
        Text(title)
          .fontSize(15)
          .fontWeight(this.navIndex === index ? FontWeight.Bold : FontWeight.Normal)
          .fontColor('#FFFFFF')
        Text(desc)
          .fontSize(10)
          .fontColor('#9DBFB3')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 11, bottom: 11, left: 12, right: 12 })
    .borderRadius(12)
    .backgroundColor(this.navIndex === index ? COLOR_SIDEBAR_ACTIVE : 'rgba(255,255,255,0.04)')
    .onClick(() => {
      this.navIndex = index
    })
  }

  @Builder
  SideBar() {
    Column({ space: 8 }) {
      // 品牌区
      Row({ space: 10 }) {
        Text('📚').fontSize(24)
        Column({ space: 2 }) {
          Text('记忆卡片制作台')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text('Memory Card Studio')
            .fontSize(10)
            .fontColor('#9DBFB3')
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ top: 8, bottom: 14, left: 6 })
      Text('')
        .fontSize(0)
      this.NavItem('📝', '录入台', '批量导入 · 实时预览', 0)
      this.NavItem('🗂', '卡片库', '搜索 · 筛选 · 编辑', 1)
      this.NavItem('🔄', '复习', '翻卡 · 洗牌 · 掌握度', 2)
      Blank()
      // 底部统计面板
      Column({ space: 7 }) {
        Text('📊 学习概览')
          .fontSize(11)
          .fontColor('#9DBFB3')
        this.StatLine('卡片总数', this.cards.length.toString() + ' 张')
        this.StatLine('标签数', this.allTags().length.toString() + ' 个')
        this.StatLine('已掌握', this.doneCount().toString() + ' 张')
      }
      .width('100%')
      .padding(12)
      .borderRadius(12)
      .backgroundColor('rgba(255,255,255,0.08)')
      .alignItems(HorizontalAlign.Start)
    }
    .width(216)
    .height('100%')
    .backgroundColor(COLOR_SIDEBAR)
    .padding({ top: 20, bottom: 16, left: 12, right: 12 })
  }

  @Builder
  StatLine(label: string, value: string) {
    Row() {
      Text(label).fontSize(12).fontColor('#CDE3DA')
      Blank()
      Text(value).fontSize(12).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
    }
    .width('100%')
  }

  // ===================== UI：页头 =====================
  @Builder
  PageHeader(icon: string, title: string, desc: string, badge: string) {
    Row({ space: 12 }) {
      Text(icon).fontSize(24)
      Column({ space: 3 }) {
        Text(title)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
        Text(desc)
          .fontSize(13)
          .fontColor(COLOR_SUB)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (badge !== '') {
        Text(badge)
          .fontSize(12)
          .fontColor(COLOR_TAG_FG)
          .backgroundColor(COLOR_TAG_BG)
          .padding({ left: 12, right: 12, top: 5, bottom: 5 })
          .borderRadius(14)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  // ===================== UI：标签胶囊 =====================
  @Builder
  TagChip(name: string) {
    Text('#' + name)
      .fontSize(11)
      .fontColor(COLOR_TAG_FG)
      .backgroundColor(COLOR_TAG_BG)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .borderRadius(10)
  }

  // 卡片库标签筛选胶囊（可点击）
  @Builder
  TagFilterChip(name: string) {
    Text(name === '' ? '全部' : '#' + name)
      .fontSize(12)
      .fontColor(this.activeTag === name ? '#FFFFFF' : COLOR_TAG_FG)
      .backgroundColor(this.activeTag === name ? COLOR_PRIMARY : COLOR_TAG_BG)
      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
      .borderRadius(14)
      .onClick(() => {
        this.activeTag = this.activeTag === name ? '' : name
      })
  }

  // 复习筛选胶囊
  @Builder
  ReviewFilterChip(label: string, value: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.reviewFilter === value ? '#FFFFFF' : COLOR_TAG_FG)
      .backgroundColor(this.reviewFilter === value ? COLOR_PRIMARY : COLOR_TAG_BG)
      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
      .borderRadius(14)
      .onClick(() => {
        this.reviewFilter = value
        this.curIndex = 0
        this.resetFlip()
      })
  }

  @Builder
  MasteryBadge(m: number) {
    Text(m === 2 ? '🟢 已掌握' : (m === 1 ? '🟡 模糊' : '⚪ 陌生'))
      .fontSize(11)
      .fontColor('#666666')
      .backgroundColor('#F2EEE3')
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .borderRadius(10)
  }

  // ===================== 页面一：录入台（左录入 / 右预览） =====================
  @Builder
  PageStudio() {
    Scroll() {
      Column() {
        Column({ space: 16 }) {
          this.PageHeader('📝', '录入台', '左侧批量输入，右侧实时预览，一键导入查重去重',
            this.cards.length.toString() + ' 张卡片')

          Row({ space: 16 }) {
            // ---------- 左栏：批量录入 ----------
            Column({ space: 12 }) {
              Column({ space: 6 }) {
                Text('录入格式')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#333333')
                Text('题干 | 答案 #标签1 #标签2')
                  .fontSize(13)
                  .fontColor(COLOR_TAG_FG)
                  .backgroundColor(COLOR_TAG_BG)
                  .fontFamily('monospace')
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                  .borderRadius(8)
                Text('· 每行一张卡片，支持全角｜分隔\n· # 后为标签，可写多个，也可不写\n· 缺少题干或答案的行会被自动跳过')
                  .fontSize(11)
                  .fontColor(COLOR_SUB)
                  .lineHeight(17)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .backgroundColor('#FFFFFF')
              .borderRadius(14)
              .padding(14)

              TextArea({ placeholder: '在此粘贴 / 输入卡片文本，右侧将实时预览…', text: this.inputText })
                .onChange((v: string) => {
                  this.inputText = v
                  this.refreshDraft()
                })
                .height(300)
                .fontSize(14)
                .backgroundColor('#FFFFFF')
                .borderRadius(14)
                .padding(14)

              Row({ space: 10 }) {
                Button('🚀 一键导入')
                  .layoutWeight(2)
                  .height(44)
                  .fontSize(15)
                  .backgroundColor(COLOR_PRIMARY)
                  .onClick(() => {
                    this.importDraft()
                  })
                Button('🧪 示例')
                  .layoutWeight(1)
                  .height(44)
                  .fontSize(14)
                  .backgroundColor('#FFFFFF')
                  .fontColor(COLOR_PRIMARY)
                  .border({ width: 1.5, color: COLOR_PRIMARY })
                  .onClick(() => {
                    this.fillSample()
                  })
                Button('🧹 清空')
                  .layoutWeight(1)
                  .height(44)
                  .fontSize(14)
                  .backgroundColor('#FFFFFF')
                  .fontColor(COLOR_SUB)
                  .border({ width: 1.5, color: '#DDDDDD' })
                  .onClick(() => {
                    this.clearInput()
                  })
              }
              .width('100%')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            // ---------- 右栏：实时预览 ----------
            Column({ space: 12 }) {
              Row({ space: 8 }) {
                Text('实时预览')
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#333333')
                Text(this.draft.length.toString() + ' 张')
                  .fontSize(11)
                  .fontColor(COLOR_TAG_FG)
                  .backgroundColor(COLOR_TAG_BG)
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .borderRadius(10)
                Blank()
                if (this.draftSkip > 0) {
                  Text(this.draftSkip.toString() + ' 行将被跳过')
                    .fontSize(11)
                    .fontColor('#C77700')
                    .backgroundColor('#FFF2D9')
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .borderRadius(10)
                }
              }
              .width('100%')

              if (this.draft.length === 0) {
                Column({ space: 8 }) {
                  Text('🪄').fontSize(44)
                  Text('在左侧输入内容后\n这里会实时渲染卡片预览')
                    .fontSize(13)
                    .fontColor(COLOR_SUB)
                    .textAlign(TextAlign.Center)
                    .lineHeight(20)
                }
                .width('100%')
                .padding({ top: 70, bottom: 70 })
                .backgroundColor('#FFFFFF')
                .borderRadius(14)
                .justifyContent(FlexAlign.Center)
              } else {
                Column({ space: 10 }) {
                  ForEach(this.draft, (c: CardItem, idx: number) => {
                    Column({ space: 7 }) {
                      Row({ space: 8 }) {
                        Text('第 ' + (idx + 1).toString() + ' 张')
                          .fontSize(10)
                          .fontColor('#B0A78F')
                        Blank()
                        Text('✓ 可导入')
                          .fontSize(10)
                          .fontColor(COLOR_TAG_FG)
                      }
                      .width('100%')
                      Text(c.question)
                        .fontSize(15)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#333333')
                        .width('100%')
                      Text(c.answer)
                        .fontSize(13)
                        .fontColor(COLOR_SUB)
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width('100%')
                      if (c.tags.length > 0) {
                        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
                          ForEach(c.tags, (t: string) => {
                            this.TagChip(t)
                          }, (t: string) => t)
                        }
                        .width('100%')
                      }
                    }
                    .width('100%')
                    .backgroundColor('#FFFFFF')
                    .borderRadius(14)
                    .padding(13)
                    .border({ width: 1, color: '#EFE8D8' })
                  }, (c: CardItem, idx: number) => idx.toString() + '-' + c.question.length.toString())
                }
                .width('100%')
              }
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }
        .constraintSize({ maxWidth: 1120 })
        .width('100%')
        .padding({ top: 28, bottom: 28, left: 22, right: 22 })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
  }

  // ===================== 页面二：卡片库 =====================
  @Builder
  PageLibrary() {
    Scroll() {
      Column() {
        Column({ space: 14 }) {
          this.PageHeader('🗂', '卡片库', '搜索、按标签筛选、行内编辑，点卡片右上角 ✕ 删除',
            this.cards.length.toString() + ' 张')

          // 搜索框
          Row({ space: 8 }) {
            Text('🔍').fontSize(15)
            TextInput({ placeholder: '搜索题干 / 答案 / 标签…', text: this.searchKw })
              .onChange((v: string) => {
                this.searchKw = v
              })
              .layoutWeight(1)
              .height(42)
              .fontSize(14)
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
          }
          .width('100%')
          .padding({ right: 10, left: 10 })
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .border({ width: 1, color: '#EFE8D8' })

          // 标签筛选
          Row({ space: 8 }) {
            Text('标签')
              .fontSize(12)
              .fontColor(COLOR_SUB)
            Scroll() {
              Row({ space: 8 }) {
                this.TagFilterChip('')
                ForEach(this.allTags(), (t: string) => {
                  this.TagFilterChip(t)
                }, (t: string) => t)
              }
            }
            .scrollable(ScrollDirection.Horizontal)
            .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          // 卡片列表
          if (this.filteredLibrary().length === 0) {
            Column({ space: 8 }) {
              Text('📭').fontSize(48)
              Text('没有找到匹配的卡片')
                .fontSize(15)
                .fontColor('#666666')
              Text('换个关键词或标签试试～')
                .fontSize(12)
                .fontColor(COLOR_SUB)
            }
            .width('100%')
            .padding({ top: 56, bottom: 56 })
            .backgroundColor('#FFFFFF')
            .borderRadius(16)
          } else {
            Column({ space: 12 }) {
              ForEach(this.filteredLibrary(), (c: CardItem) => {
                if (this.editingId === c.id) {
                  // ---------- 行内编辑模式 ----------
                  Column({ space: 10 }) {
                    Text('✏️ 编辑卡片 #' + c.id.toString())
                      .fontSize(13)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(COLOR_TAG_FG)
                      .width('100%')
                    TextInput({ text: this.editQ })
                      .onChange((v: string) => {
                        this.editQ = v
                      })
                      .height(42)
                      .fontSize(14)
                      .backgroundColor(COLOR_INPUT_BG)
                      .borderRadius(10)
                    TextArea({ text: this.editA })
                      .onChange((v: string) => {
                        this.editA = v
                      })
                      .height(90)
                      .fontSize(13)
                      .backgroundColor(COLOR_INPUT_BG)
                      .borderRadius(10)
                    TextInput({ placeholder: '标签（空格/逗号分隔，可带 #）', text: this.editTags })
                      .onChange((v: string) => {
                        this.editTags = v
                      })
                      .height(42)
                      .fontSize(13)
                      .backgroundColor(COLOR_INPUT_BG)
                      .borderRadius(10)
                    Row({ space: 10 }) {
                      Button('取消')
                        .layoutWeight(1)
                        .height(38)
                        .fontSize(13)
                        .backgroundColor(COLOR_INPUT_BG)
                        .fontColor(COLOR_SUB)
                        .onClick(() => {
                          this.editingId = -1
                        })
                      Button('保存修改')
                        .layoutWeight(2)
                        .height(38)
                        .fontSize(13)
                        .backgroundColor(COLOR_PRIMARY)
                        .onClick(() => {
                          this.saveEdit()
                        })
                    }
                    .width('100%')
                  }
                  .width('100%')
                  .backgroundColor('#FFFFFF')
                  .borderRadius(16)
                  .padding(14)
                  .border({ width: 1.5, color: COLOR_PRIMARY })
                } else {
                  // ---------- 普通展示模式 ----------
                  Column({ space: 8 }) {
                    Row({ space: 10 }) {
                      Text(c.question)
                        .fontSize(16)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#333333')
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .layoutWeight(1)
                      Text('✕')
                        .fontSize(15)
                        .fontColor('#B9B9B9')
                        .padding({ left: 8, right: 4 })
                        .onClick(() => {
                          this.removeCard(c.id)
                        })
                    }
                    .width('100%')

                    Text(c.answer)
                      .fontSize(13)
                      .fontColor(COLOR_SUB)
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')

                    Row({ space: 8 }) {
                      if (c.tags.length > 0) {
                        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
                          ForEach(c.tags, (t: string) => {
                            this.TagChip(t)
                          }, (t: string) => t)
                        }
                        .layoutWeight(1)
                      } else {
                        Blank()
                      }
                      this.MasteryBadge(c.mastery)
                      Text('编辑')
                        .fontSize(12)
                        .fontColor(COLOR_PRIMARY)
                        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                        .borderRadius(10)
                        .border({ width: 1, color: COLOR_PRIMARY })
                        .onClick(() => {
                          this.startEdit(c)
                        })
                    }
                    .width('100%')
                    .alignItems(VerticalAlign.Center)
                  }
                  .width('100%')
                  .backgroundColor('#FFFFFF')
                  .borderRadius(16)
                  .padding(14)
                  .shadow({ radius: 10, color: 'rgba(63,163,114,0.08)', offsetY: 3 })
                }
              }, (c: CardItem) => {
                return c.id.toString() + '-' + c.mastery.toString() + '-' +
                  c.question.length.toString() + '-' + c.answer.length.toString() + '-' +
                  c.tags.length.toString()
              })
            }
            .width('100%')
          }
        }
        .constraintSize({ maxWidth: 1120 })
        .width('100%')
        .padding({ top: 28, bottom: 28, left: 22, right: 22 })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
  }

  // ===================== 页面三：复习 =====================
  @Builder
  CardFront(card: CardItem) {
    Column({ space: 14 }) {
      Text('💡 题目')
        .fontSize(14)
        .fontColor('#CDE8DC')
      Text(card.question)
        .fontSize(21)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .textAlign(TextAlign.Center)
        .padding({ left: 16, right: 16 })
      if (card.tags.length > 0) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
          ForEach(card.tags, (t: string) => {
            Text('#' + t)
              .fontSize(11)
              .fontColor('#D8F3E7')
              .backgroundColor('rgba(255,255,255,0.14)')
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .borderRadius(10)
              .margin({ left: 4, right: 4 })
          }, (t: string) => t)
        }
        .width('80%')
      }
      Text('点击卡片揭晓答案 👆')
        .fontSize(12)
        .fontColor('#9DBFB0')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(COLOR_FRONT)
    .borderRadius(22)
    .shadow({ radius: 16, color: 'rgba(61,122,99,0.25)', offsetY: 6 })
  }

  @Builder
  CardBack(card: CardItem) {
    Column({ space: 14 }) {
      Text('📌 答案')
        .fontSize(14)
        .fontColor('#B08900')
      Text(card.answer)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_BACK_TEXT)
        .textAlign(TextAlign.Center)
        .padding({ left: 16, right: 16 })
      Text('这张卡片掌握得怎么样？👇')
        .fontSize(12)
        .fontColor('#C4A93F')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(COLOR_BACK)
    .borderRadius(22)
    .rotate({ y: 1, angle: 180 }) // 预旋转 180°，翻过去后文字方向正确
    .shadow({ radius: 16, color: 'rgba(194,169,63,0.25)', offsetY: 6 })
  }

  @Builder
  PageReview() {
    Scroll() {
      Column() {
        Column({ space: 16 }) {
          this.PageHeader('🔄', '复习', '点击卡片翻转；标记掌握度后自动跳到下一张', '')

          // 筛选 + 洗牌
          Row({ space: 8 }) {
            this.ReviewFilterChip('全部', 'all')
            this.ReviewFilterChip('待巩固', 'todo')
            this.ReviewFilterChip('已掌握', 'done')
            Blank()
            Text(this.shuffled ? '🔀 乱序中' : '🔀 洗牌')
              .fontSize(12)
              .fontColor(this.shuffled ? '#FFFFFF' : COLOR_PRIMARY)
              .backgroundColor(this.shuffled ? COLOR_PRIMARY : COLOR_TAG_BG)
              .padding({ left: 12, right: 12, top: 5, bottom: 5 })
              .borderRadius(14)
              .onClick(() => {
                this.toggleShuffle()
              })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          if (this.reviewList().length === 0) {
            Column({ space: 10 }) {
              Text('🎉').fontSize(52)
              Text(this.reviewFilter === 'done' ? '还没有已掌握的卡片' : '没有待复习的卡片')
                .fontSize(15)
                .fontColor('#666666')
              Text('去「录入台」添加新卡片吧～')
                .fontSize(12)
                .fontColor(COLOR_SUB)
              Button('去录入')
                .margin({ top: 6 })
                .height(40)
                .padding({ left: 24, right: 24 })
                .backgroundColor(COLOR_PRIMARY)
                .onClick(() => {
                  this.navIndex = 0
                })
            }
            .width('100%')
            .padding({ top: 60, bottom: 60 })
            .backgroundColor('#FFFFFF')
            .borderRadius(16)
          } else {
            Text('第 ' + (this.curPos(this.reviewList().length) + 1).toString() + ' / ' +
              this.reviewList().length.toString() + ' 张')
              .fontSize(13)
              .fontColor('#6B5B3E')
              .backgroundColor('#F0EAD9')
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .borderRadius(14)

            // 可翻转卡片
            Column() {
              if (this.showFront) {
                this.CardFront(this.reviewList()[this.curPos(this.reviewList().length)])
              } else {
                this.CardBack(this.reviewList()[this.curPos(this.reviewList().length)])
              }
            }
            .width('100%')
            .height(320)
            .rotate({ y: 1, angle: this.flipAngle, perspective: 900 })
            .onClick(() => {
              this.flipCard()
            })

            // 掌握度三档标记
            Text('标记这张卡片的掌握程度')
              .fontSize(12)
              .fontColor(COLOR_SUB)
            Row({ space: 12 }) {
              Button('😅 陌生')
                .layoutWeight(1)
                .height(42)
                .fontSize(14)
                .backgroundColor('#FFFFFF')
                .fontColor('#C77700')
                .border({ width: 1.5, color: '#E8B04B' })
                .onClick(() => {
                  this.mark(0)
                })
              Button('🤔 模糊')
                .layoutWeight(1)
                .height(42)
                .fontSize(14)
                .backgroundColor('#FFFFFF')
                .fontColor('#4A7EBB')
                .border({ width: 1.5, color: '#7FA8D9' })
                .onClick(() => {
                  this.mark(1)
                })
              Button('😄 已掌握')
                .layoutWeight(1)
                .height(42)
                .fontSize(14)
                .backgroundColor(COLOR_PRIMARY)
                .fontColor('#FFFFFF')
                .onClick(() => {
                  this.mark(2)
                })
            }
            .width('100%')

            // 上一张 / 下一张
            Row({ space: 16 }) {
              Button('← 上一张')
                .layoutWeight(1)
                .height(42)
                .fontSize(14)
                .backgroundColor('#FFFFFF')
                .fontColor(COLOR_PRIMARY)
                .border({ width: 1.5, color: COLOR_PRIMARY })
                .onClick(() => {
                  this.changeCard(-1)
                })
              Button('下一张 →')
                .layoutWeight(1)
                .height(42)
                .fontSize(14)
                .backgroundColor(COLOR_PRIMARY)
                .fontColor('#FFFFFF')
                .onClick(() => {
                  this.changeCard(1)
                })
            }
            .width('100%')
          }
        }
        .constraintSize({ maxWidth: 720 })
        .width('100%')
        .padding({ top: 28, bottom: 28, left: 22, right: 22 })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
  }

  // ===================== 主结构：侧边栏 + 内容区 =====================
  build() {
    Row() {
      this.SideBar()
      Column() {
        if (this.navIndex === 0) {
          this.PageStudio()
        } else if (this.navIndex === 1) {
          this.PageLibrary()
        } else {
          this.PageReview()
        }
      }
      .layoutWeight(1)
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG)
  }
}
