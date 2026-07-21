// Hugeicons wrapper components — the icon set behind `@/shared/icons`.
//
// Each export keeps the icon NAME the app already imports, but renders the
// Hugeicons glyph via `<HugeiconsIcon icon={...} />`. Call sites are unchanged
// (`<Store size={40} className="..." />`), and swapping the underlying glyph is
// a one-line edit here. Names/targets are seeded from a lucide->hugeicons map;
// the `size`/`className`/`strokeWidth`/`color` props pass straight through.
//
// This file is generated — edit the source map + regenerate, or hand-tweak an
// individual mapping here.

import { HugeiconsIcon, type HugeiconsProps } from "@hugeicons/react";
import type { ReactElement } from "react";
import {
  Album01Icon as _Album01Icon,
  Alert02Icon as _Alert02Icon,
  AlertCircleIcon as _AlertCircleIcon,
  AnalyticsDownIcon as _AnalyticsDownIcon,
  AnalyticsUpIcon as _AnalyticsUpIcon,
  ArmchairIcon as _ArmchairIcon,
  ArrowDown01Icon as _ArrowDown01Icon,
  ArrowDownLeft01Icon as _ArrowDownLeft01Icon,
  ArrowDownToLineIcon as _ArrowDownToLineIcon,
  ArrowLeft01Icon as _ArrowLeft01Icon,
  ArrowLeftRightIcon as _ArrowLeftRightIcon,
  ArrowRight01Icon as _ArrowRight01Icon,
  ArrowUp01Icon as _ArrowUp01Icon,
  ArrowUpFromLineIcon as _ArrowUpFromLineIcon,
  ArrowUpRight01Icon as _ArrowUpRight01Icon,
  AtSignIcon as _AtSignIcon,
  BadgeCheckIcon as _BadgeCheckIcon,
  BadgeIndianRupeeIcon as _BadgeIndianRupeeIcon,
  BanknoteIcon as _BanknoteIcon,
  BarChartIcon as _BarChartIcon,
  BarcodeScanIcon as _BarcodeScanIcon,
  BellIcon as _BellIcon,
  Bone01Icon as _Bone01Icon,
  BookOpen01Icon as _BookOpen01Icon,
  BookOpenTextIcon as _BookOpenTextIcon,
  BoxesIcon as _BoxesIcon,
  BubbleChatIcon as _BubbleChatIcon,
  Building02Icon as _Building02Icon,
  Calculator01Icon as _Calculator01Icon,
  Calendar01Icon as _Calendar01Icon,
  CalendarDaysIcon as _CalendarDaysIcon,
  CalendarRemove01Icon as _CalendarRemove01Icon,
  Call02Icon as _Call02Icon,
  Cancel01Icon as _Cancel01Icon,
  CancelCircleIcon as _CancelCircleIcon,
  Car01Icon as _Car01Icon,
  ChartLineData01Icon as _ChartLineData01Icon,
  CheckmarkCircle02Icon as _CheckmarkCircle02Icon,
  ChevronDownIcon as _ChevronDownIcon,
  ChevronLeftIcon as _ChevronLeftIcon,
  ChevronRightIcon as _ChevronRightIcon,
  CircleDotIcon as _CircleDotIcon,
  CircleIcon as _CircleIcon,
  ClipboardListIcon as _ClipboardListIcon,
  Clock01Icon as _Clock01Icon,
  Coffee01Icon as _Coffee01Icon,
  ConciergeBellIcon as _ConciergeBellIcon,
  Copy01Icon as _Copy01Icon,
  CpuIcon as _CpuIcon,
  CreditCardIcon as _CreditCardIcon,
  CroissantIcon as _CroissantIcon,
  Cursor01Icon as _Cursor01Icon,
  DashboardSquare01Icon as _DashboardSquare01Icon,
  Delete02Icon as _Delete02Icon,
  DeliveryTruck01Icon as _DeliveryTruck01Icon,
  Download01Icon as _Download01Icon,
  Dumbbell01Icon as _Dumbbell01Icon,
  ExternalLinkIcon as _ExternalLinkIcon,
  EyeIcon as _EyeIcon,
  File01Icon as _File01Icon,
  FileUpIcon as _FileUpIcon,
  FlowerIcon as _FlowerIcon,
  FolderTreeIcon as _FolderTreeIcon,
  GemIcon as _GemIcon,
  GiftIcon as _GiftIcon,
  HammerIcon as _HammerIcon,
  HeartIcon as _HeartIcon,
  HierarchyIcon as _HierarchyIcon,
  HistoryIcon as _HistoryIcon,
  IceCream01Icon as _IceCream01Icon,
  Idea01Icon as _Idea01Icon,
  ImageAdd01Icon as _ImageAdd01Icon,
  ImageNotFound01Icon as _ImageNotFound01Icon,
  InboxIcon as _InboxIcon,
  InformationCircleIcon as _InformationCircleIcon,
  KitchenUtensilsIcon as _KitchenUtensilsIcon,
  LandmarkIcon as _LandmarkIcon,
  LaptopIcon as _LaptopIcon,
  LayoutGridIcon as _LayoutGridIcon,
  Leaf01Icon as _Leaf01Icon,
  Link02Icon as _Link02Icon,
  ListRestartIcon as _ListRestartIcon,
  ListViewIcon as _ListViewIcon,
  Loading03Icon as _Loading03Icon,
  LockIcon as _LockIcon,
  Login03Icon as _Login03Icon,
  Logout03Icon as _Logout03Icon,
  Mail01Icon as _Mail01Icon,
  MapPinIcon as _MapPinIcon,
  Maximize02Icon as _Maximize02Icon,
  Menu01Icon as _Menu01Icon,
  Message01Icon as _Message01Icon,
  Minimize02Icon as _Minimize02Icon,
  MinusSignIcon as _MinusSignIcon,
  Navigation03Icon as _Navigation03Icon,
  NoteEditIcon as _NoteEditIcon,
  Package01Icon as _Package01Icon,
  PackageAddIcon as _PackageAddIcon,
  PackageDeliveredIcon as _PackageDeliveredIcon,
  PackageRemove01Icon as _PackageRemove01Icon,
  PackageRemoveIcon as _PackageRemoveIcon,
  PaintBoardIcon as _PaintBoardIcon,
  PaintBrush01Icon as _PaintBrush01Icon,
  PauseIcon as _PauseIcon,
  PencilEdit01Icon as _PencilEdit01Icon,
  PercentIcon as _PercentIcon,
  PillIcon as _PillIcon,
  PlaneIcon as _PlaneIcon,
  PlusSignIcon as _PlusSignIcon,
  PowerIcon as _PowerIcon,
  PrinterIcon as _PrinterIcon,
  QuoteDownIcon as _QuoteDownIcon,
  ReceiptIndianRupeeIcon as _ReceiptIndianRupeeIcon,
  ReceiptTextIcon as _ReceiptTextIcon,
  RefreshIcon as _RefreshIcon,
  RefrigeratorIcon as _RefrigeratorIcon,
  RepeatIcon as _RepeatIcon,
  RotateLeft01Icon as _RotateLeft01Icon,
  RunningShoesIcon as _RunningShoesIcon,
  RupeeIcon as _RupeeIcon,
  ScanEyeIcon as _ScanEyeIcon,
  ScanIcon as _ScanIcon,
  Scroll01Icon as _Scroll01Icon,
  Search01Icon as _Search01Icon,
  SecurityCheckIcon as _SecurityCheckIcon,
  SecurityWarningIcon as _SecurityWarningIcon,
  Settings01Icon as _Settings01Icon,
  Share01Icon as _Share01Icon,
  ShoppingBag01Icon as _ShoppingBag01Icon,
  ShoppingCart01Icon as _ShoppingCart01Icon,
  SlidersHorizontalIcon as _SlidersHorizontalIcon,
  SmartPhone01Icon as _SmartPhone01Icon,
  SparklesIcon as _SparklesIcon,
  SprayCanIcon as _SprayCanIcon,
  SquareUnlock01Icon as _SquareUnlock01Icon,
  StarHalfIcon as _StarHalfIcon,
  StarIcon as _StarIcon,
  SteakIcon as _SteakIcon,
  Store01Icon as _Store01Icon,
  TShirtIcon as _TShirtIcon,
  Tag01Icon as _Tag01Icon,
  Target01Icon as _Target01Icon,
  Tick02Icon as _Tick02Icon,
  TickDouble01Icon as _TickDouble01Icon,
  Ticket01Icon as _Ticket01Icon,
  Timer01Icon as _Timer01Icon,
  ToyBrickIcon as _ToyBrickIcon,
  Undo02Icon as _Undo02Icon,
  Upload01Icon as _Upload01Icon,
  UserAdd01Icon as _UserAdd01Icon,
  UserCircleIcon as _UserCircleIcon,
  UserEdit01Icon as _UserEdit01Icon,
  UserGroupIcon as _UserGroupIcon,
  UserIcon as _UserIcon,
  UserSettings01Icon as _UserSettings01Icon,
  Wallet01Icon as _Wallet01Icon,
  Wifi01Icon as _Wifi01Icon,
  WifiOff01Icon as _WifiOff01Icon,
} from "@hugeicons/core-free-icons";

/** Props accepted by every icon in `@/shared/icons` (Hugeicons, minus `icon`). */
export type IconProps = Omit<HugeiconsProps, "icon">;

/** Back-compat alias for code that typed an icon component as `LucideIcon`. */
export type LucideIcon = (props: IconProps) => ReactElement;

export function AlertCircle(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_AlertCircleIcon} {...props} />;
}
export function AlertTriangle(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Alert02Icon} {...props} />;
}
export function Armchair(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ArmchairIcon} {...props} />;
}
export function ArrowDown(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ArrowDown01Icon} {...props} />;
}
export function ArrowDownLeft(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ArrowDownLeft01Icon} {...props} />;
}
export function ArrowDownToLine(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ArrowDownToLineIcon} {...props} />;
}
export function ArrowLeft(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ArrowLeft01Icon} {...props} />;
}
export function ArrowLeftRight(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ArrowLeftRightIcon} {...props} />;
}
export function ArrowRight(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ArrowRight01Icon} {...props} />;
}
export function ArrowUp(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ArrowUp01Icon} {...props} />;
}
export function ArrowUpFromLine(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ArrowUpFromLineIcon} {...props} />;
}
export function ArrowUpRight(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ArrowUpRight01Icon} {...props} />;
}
export function AtSign(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_AtSignIcon} {...props} />;
}
export function BadgeCheck(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_BadgeCheckIcon} {...props} />;
}
export function BadgeIndianRupee(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_BadgeIndianRupeeIcon} {...props} />;
}
export function Banknote(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_BanknoteIcon} {...props} />;
}
export function BarChart3(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_BarChartIcon} {...props} />;
}
export function Beef(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_SteakIcon} {...props} />;
}
export function Bell(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_BellIcon} {...props} />;
}
export function BookOpen(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_BookOpen01Icon} {...props} />;
}
export function BookText(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_BookOpenTextIcon} {...props} />;
}
export function Boxes(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_BoxesIcon} {...props} />;
}
export function Building2(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Building02Icon} {...props} />;
}
export function Calculator(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Calculator01Icon} {...props} />;
}
export function Calendar(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Calendar01Icon} {...props} />;
}
export function CalendarDays(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_CalendarDaysIcon} {...props} />;
}
export function CalendarX2(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_CalendarRemove01Icon} {...props} />;
}
export function Car(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Car01Icon} {...props} />;
}
export function Check(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Tick02Icon} {...props} />;
}
export function CheckCheck(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_TickDouble01Icon} {...props} />;
}
export function CheckCircle2(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_CheckmarkCircle02Icon} {...props} />;
}
export function ChevronDown(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ChevronDownIcon} {...props} />;
}
export function ChevronLeft(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ChevronLeftIcon} {...props} />;
}
export function ChevronRight(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ChevronRightIcon} {...props} />;
}
export function Circle(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_CircleIcon} {...props} />;
}
export function CircleDot(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_CircleDotIcon} {...props} />;
}
export function ClipboardList(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ClipboardListIcon} {...props} />;
}
export function Clock(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Clock01Icon} {...props} />;
}
export function Coffee(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Coffee01Icon} {...props} />;
}
export function ConciergeBell(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ConciergeBellIcon} {...props} />;
}
export function Copy(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Copy01Icon} {...props} />;
}
export function Cpu(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_CpuIcon} {...props} />;
}
export function CreditCard(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_CreditCardIcon} {...props} />;
}
export function Croissant(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_CroissantIcon} {...props} />;
}
export function Download(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Download01Icon} {...props} />;
}
export function Dumbbell(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Dumbbell01Icon} {...props} />;
}
export function ExternalLink(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ExternalLinkIcon} {...props} />;
}
export function Eye(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_EyeIcon} {...props} />;
}
export function FileText(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_File01Icon} {...props} />;
}
export function FileUp(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_FileUpIcon} {...props} />;
}
export function Flower2(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_FlowerIcon} {...props} />;
}
export function FolderTree(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_FolderTreeIcon} {...props} />;
}
export function Footprints(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_RunningShoesIcon} {...props} />;
}
export function Gem(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_GemIcon} {...props} />;
}
export function Gift(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_GiftIcon} {...props} />;
}
export function Hammer(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_HammerIcon} {...props} />;
}
export function Heart(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_HeartIcon} {...props} />;
}
export function History(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_HistoryIcon} {...props} />;
}
export function IceCreamCone(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_IceCream01Icon} {...props} />;
}
export function ImageOff(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ImageNotFound01Icon} {...props} />;
}
export function ImagePlus(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ImageAdd01Icon} {...props} />;
}
export function Images(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Album01Icon} {...props} />;
}
export function Inbox(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_InboxIcon} {...props} />;
}
export function IndianRupee(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_RupeeIcon} {...props} />;
}
export function Info(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_InformationCircleIcon} {...props} />;
}
export function Landmark(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_LandmarkIcon} {...props} />;
}
export function Laptop(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_LaptopIcon} {...props} />;
}
export function LayoutDashboard(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_DashboardSquare01Icon} {...props} />;
}
export function LayoutGrid(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_LayoutGridIcon} {...props} />;
}
export function Lightbulb(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Idea01Icon} {...props} />;
}
export function LineChart(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ChartLineData01Icon} {...props} />;
}
export function Link2(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Link02Icon} {...props} />;
}
export function List(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ListViewIcon} {...props} />;
}
export function ListRestart(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ListRestartIcon} {...props} />;
}
export function Loader2(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Loading03Icon} {...props} />;
}
export function Lock(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_LockIcon} {...props} />;
}
export function LockOpen(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_SquareUnlock01Icon} {...props} />;
}
export function LogIn(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Login03Icon} {...props} />;
}
export function LogOut(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Logout03Icon} {...props} />;
}
export function Mail(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Mail01Icon} {...props} />;
}
export function MapPin(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_MapPinIcon} {...props} />;
}
export function Maximize2(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Maximize02Icon} {...props} />;
}
export function Menu(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Menu01Icon} {...props} />;
}
export function MessageCircle(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_BubbleChatIcon} {...props} />;
}
export function MessageSquare(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Message01Icon} {...props} />;
}
export function MessageSquareQuote(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_QuoteDownIcon} {...props} />;
}
export function Minimize2(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Minimize02Icon} {...props} />;
}
export function Minus(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_MinusSignIcon} {...props} />;
}
export function MousePointerClick(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Cursor01Icon} {...props} />;
}
export function Network(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_HierarchyIcon} {...props} />;
}
export function NotebookPen(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_NoteEditIcon} {...props} />;
}
export function Package(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Package01Icon} {...props} />;
}
export function PackageCheck(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_PackageDeliveredIcon} {...props} />;
}
export function PackageMinus(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_PackageRemoveIcon} {...props} />;
}
export function PackagePlus(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_PackageAddIcon} {...props} />;
}
export function PackageX(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_PackageRemove01Icon} {...props} />;
}
export function PaintRoller(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_PaintBrush01Icon} {...props} />;
}
export function Palette(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_PaintBoardIcon} {...props} />;
}
export function Pause(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_PauseIcon} {...props} />;
}
export function PawPrint(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Bone01Icon} {...props} />;
}
export function Pencil(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_PencilEdit01Icon} {...props} />;
}
export function Percent(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_PercentIcon} {...props} />;
}
export function Phone(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Call02Icon} {...props} />;
}
export function Pill(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_PillIcon} {...props} />;
}
export function Plane(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_PlaneIcon} {...props} />;
}
export function Plus(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_PlusSignIcon} {...props} />;
}
export function Power(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_PowerIcon} {...props} />;
}
export function Printer(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_PrinterIcon} {...props} />;
}
export function Receipt(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ReceiptTextIcon} {...props} />;
}
export function ReceiptIndianRupee(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ReceiptIndianRupeeIcon} {...props} />;
}
export function ReceiptText(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ReceiptTextIcon} {...props} />;
}
export function RefreshCw(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_RefreshIcon} {...props} />;
}
export function Refrigerator(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_RefrigeratorIcon} {...props} />;
}
export function Repeat(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_RepeatIcon} {...props} />;
}
export function RotateCcw(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_RotateLeft01Icon} {...props} />;
}
export function ScanBarcode(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_BarcodeScanIcon} {...props} />;
}
export function ScanEye(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ScanEyeIcon} {...props} />;
}
export function ScanLine(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ScanIcon} {...props} />;
}
export function ScrollText(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Scroll01Icon} {...props} />;
}
export function Search(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Search01Icon} {...props} />;
}
export function Send(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Navigation03Icon} {...props} />;
}
export function Settings(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Settings01Icon} {...props} />;
}
export function Share2(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Share01Icon} {...props} />;
}
export function ShieldAlert(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_SecurityWarningIcon} {...props} />;
}
export function ShieldCheck(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_SecurityCheckIcon} {...props} />;
}
export function Shirt(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_TShirtIcon} {...props} />;
}
export function ShoppingBag(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ShoppingBag01Icon} {...props} />;
}
export function ShoppingCart(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ShoppingCart01Icon} {...props} />;
}
export function SlidersHorizontal(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_SlidersHorizontalIcon} {...props} />;
}
export function Smartphone(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_SmartPhone01Icon} {...props} />;
}
export function Sparkles(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_SparklesIcon} {...props} />;
}
export function SprayCan(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_SprayCanIcon} {...props} />;
}
export function Sprout(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Leaf01Icon} {...props} />;
}
export function Star(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_StarIcon} {...props} />;
}
export function StarHalf(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_StarHalfIcon} {...props} />;
}
export function Store(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Store01Icon} {...props} />;
}
export function Tag(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Tag01Icon} {...props} />;
}
export function Target(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Target01Icon} {...props} />;
}
export function Ticket(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Ticket01Icon} {...props} />;
}
export function Timer(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Timer01Icon} {...props} />;
}
export function ToyBrick(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_ToyBrickIcon} {...props} />;
}
export function Trash2(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Delete02Icon} {...props} />;
}
export function TrendingDown(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_AnalyticsDownIcon} {...props} />;
}
export function TrendingUp(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_AnalyticsUpIcon} {...props} />;
}
export function TriangleAlert(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Alert02Icon} {...props} />;
}
export function Truck(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_DeliveryTruck01Icon} {...props} />;
}
export function Undo2(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Undo02Icon} {...props} />;
}
export function Upload(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Upload01Icon} {...props} />;
}
export function User(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_UserIcon} {...props} />;
}
export function UserCog(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_UserSettings01Icon} {...props} />;
}
export function UserPen(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_UserEdit01Icon} {...props} />;
}
export function UserPlus(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_UserAdd01Icon} {...props} />;
}
export function UserRound(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_UserCircleIcon} {...props} />;
}
export function Users(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_UserGroupIcon} {...props} />;
}
export function Utensils(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_KitchenUtensilsIcon} {...props} />;
}
export function Wallet(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Wallet01Icon} {...props} />;
}
export function Wifi(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Wifi01Icon} {...props} />;
}
export function WifiOff(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_WifiOff01Icon} {...props} />;
}
export function X(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_Cancel01Icon} {...props} />;
}
export function XCircle(props: IconProps): ReactElement {
  return <HugeiconsIcon icon={_CancelCircleIcon} {...props} />;
}
